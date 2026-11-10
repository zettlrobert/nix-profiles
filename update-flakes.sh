#!/usr/bin/env bash
# Update every flake.lock in this repo and commit the result.
#
# Flakes depend on each other via path: inputs, so they are updated
# leaf-first:  freecad-mcp, llama-cpp, core-packages -> profiles/*
# Updating a parent before its child would lock the parent against
# the child's stale lock and leave two nixpkgs revisions in the repo.
#
# After updating, every profile is dry-run built for each system it
# declares, to list what cache.nixos.org does not have yet. nixpkgs-unstable
# advances before Hydra has built every leaf package, so a fresh bump can
# mean compiling things like biome locally for a day or two.
#
# Usage:  ./update-flakes.sh                  update, check cache, commit
#         ./update-flakes.sh --no-commit      update and check only
#         ./update-flakes.sh --allow-builds   commit even if things would build

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

commit=true
allow_builds=false
for arg in "$@"; do
  case "$arg" in
    --no-commit) commit=false ;;
    --allow-builds) allow_builds=true ;;
    *) printf 'unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

# Derivations that always build locally, matched as "<system> <name>".
# Everything else that would build means the binary cache is behind.
expected_local=(
  '* source'                  # flake sources copied into the store
  '* core'                    # our buildEnvs and wrappers
  '* fara' '* mac-mini' '* midgard' '* nebula'
  '* githooks'                # github:zettlrobert/githooks, not on cache.nixos.org
  '* easyeffects-wrapped-*'   # core-packages overlay around the cached easyeffects
  '* *freecad-robust-mcp-*'   # packages/freecad-mcp, not in nixpkgs
  '* crush-*'                 # unfree (FSL-1.1-MIT), Hydra never builds it
  '* *yamllint-*'             # githooks overrides yamllint until nixpkgs has 1.38.0
  'aarch64-linux atuin-*'     # nebula skips a flaky test, which changes the hash
)
is_expected() {
  local pat
  for pat in "${expected_local[@]}"; do
    # shellcheck disable=SC2053 # glob match on purpose
    [[ "$1" == $pat ]] && return 0
  done
  return 1
}

# ── output helpers ──────────────────────────────────────────────────
if [[ -t 1 ]]; then
  bold=$'\e[1m' dim=$'\e[2m' red=$'\e[31m' green=$'\e[32m' yellow=$'\e[33m' blue=$'\e[34m' reset=$'\e[0m'
else
  bold='' dim='' red='' green='' yellow='' blue='' reset=''
fi
header() { printf '\n%s%s%s\n' "$bold$blue" "$*" "$reset"; }
step()   { printf '%s[%d/%d]%s %s%s%s\n' "$dim" "$1" "$2" "$reset" "$bold" "$3" "$reset"; }
ok()     { printf '  %s✔%s %s\n' "$green" "$reset" "$*"; }
skip()   { printf '  %s·%s %s\n' "$dim" "$reset" "$*"; }
die()    { printf '%s✘ %s%s\n' "$red" "$*" "$reset" >&2; exit 1; }

# ── preflight ───────────────────────────────────────────────────────
# Refuse to run on a dirty tree: the lock would be computed from
# uncommitted flake.nix changes and committed without them.
if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  git status --short >&2
  die "working tree has uncommitted changes, commit or stash them first"
fi

# Dependency order. Add new package flakes here; profiles are discovered.
flake_dirs=(
  packages/freecad-mcp
  packages/llama-cpp
  packages/core-packages
)
while IFS= read -r dir; do
  flake_dirs+=("$dir")
done < <(find profiles -mindepth 2 -name flake.nix -exec dirname {} \; | sort)

# Catch any flake not covered by the list above.
mapfile -t all_dirs < <(find . -name flake.nix -not -path './.git/*' -exec dirname {} \; | sed 's#^\./##' | sort)
for dir in "${all_dirs[@]}"; do
  [[ " ${flake_dirs[*]} " =~ " ${dir} " ]] || die "$dir has a flake.nix but is not in the update order, add it to flake_dirs"
done

# ── update ──────────────────────────────────────────────────────────
header "Updating ${#flake_dirs[@]} flakes (leaf first)"
total=${#flake_dirs[@]}
i=0
for dir in "${flake_dirs[@]}"; do
  i=$((i + 1))
  step "$i" "$total" "$dir"
  nix flake update --flake "./$dir" 2>&1 | sed "s/^/  ${dim}│${reset} /"
  if git diff --quiet -- "$dir/flake.lock"; then
    skip "unchanged"
  else
    ok "updated"
  fi
done

# ── cache check ─────────────────────────────────────────────────────
# Dry-run counts paths already in the local store as available, so a
# re-run after building something here can miss it for x86_64-linux.
# Right after a bump the new hashes are not local yet, so it is accurate.
header "Checking what cache.nixos.org is missing"
unexpected=()
failed=()
for dir in "${flake_dirs[@]}"; do
  [[ "$dir" == profiles/* ]] || continue
  mapfile -t systems < <(nix eval --raw "./$dir#packages" --apply 'p: builtins.concatStringsSep "\n" (builtins.attrNames p)')
  for system in "${systems[@]}"; do
    if ! out=$(nix build --dry-run "./$dir#packages.$system.default" 2>&1); then
      printf '  %s✘%s %s %s(%s)%s failed to evaluate:\n' "$red" "$reset" "$dir" "$dim" "$system" "$reset"
      printf '%s\n' "$out" | grep -E '^ *error:' | tail -1 | sed "s/^ */    ${dim}│${reset} /"
      failed+=("$dir ($system)")
      continue
    fi
    mapfile -t builds < <(printf '%s\n' "$out" |
      awk '/will be built:/ {on=1; next} /will be fetched|^[^ ]/ {on=0} on && /\.drv$/' |
      sed -E 's#^ */nix/store/[a-z0-9]{32}-##; s#\.drv$##')
    missing=()
    for name in "${builds[@]}"; do
      is_expected "$system $name" || missing+=("$name")
    done
    if ((${#missing[@]})); then
      printf '  %s⚠%s %s %s(%s)%s builds: %s\n' "$yellow" "$reset" "$dir" "$dim" "$system" "$reset" "${missing[*]}"
      unexpected+=("${missing[@]/#/$system }")
    else
      ok "$dir ${dim}($system)${reset}"
    fi
  done
done

if ((${#failed[@]})); then
  echo
  if $commit && ! git diff --quiet -- '*/flake.lock'; then
    git checkout -- '*/flake.lock'
    die "${#failed[@]} profile output(s) failed to evaluate, locks reverted"
  fi
  die "${#failed[@]} profile output(s) failed to evaluate"
fi

if ((${#unexpected[@]})) && $commit && ! $allow_builds && ! git diff --quiet -- '*/flake.lock'; then
  echo
  printf '  %s⚠%s %d package(s) would compile locally. Waiting a day or two usually lets Hydra catch up.\n' \
    "$yellow" "$reset" "${#unexpected[@]}"
  answer=n
  [[ -t 0 ]] && read -r -p "  Commit the new locks anyway? [y/N] " answer
  if [[ "$answer" != [yY]* ]]; then
    git checkout -- '*/flake.lock'
    die "locks reverted, re-run later or pass --allow-builds"
  fi
fi

# ── commit ──────────────────────────────────────────────────────────
git add -- '*/flake.lock'

header "Summary"
if git diff --cached --quiet; then
  skip "all flake.lock files already up to date, nothing to commit"
  exit 0
fi

git diff --cached --stat --color=always | sed 's/^/  /'

if $commit; then
  echo
  git commit -q -m "chore: update nix flake locks"
  ok "committed $(git rev-parse --short HEAD): chore: update nix flake locks"
else
  echo
  printf '  %s⚠%s staged, not committed (--no-commit)\n' "$yellow" "$reset"
fi
