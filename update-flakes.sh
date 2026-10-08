#!/usr/bin/env bash
# Update every flake.lock in this repo and commit the result.
#
# Flakes depend on each other via path: inputs, so they are updated
# leaf-first:  freecad-mcp -> core-packages -> profiles/*
# Updating a parent before its child would lock the parent against
# the child's stale lock and leave two nixpkgs revisions in the repo.
#
# Usage:  ./update-flakes.sh               update and commit
#         ./update-flakes.sh --no-commit   update only

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

commit=true
[[ "${1:-}" == "--no-commit" ]] && commit=false

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
  nix flake update --flake "$dir" 2>&1 | sed "s/^/  ${dim}│${reset} /"
  if git diff --quiet -- "$dir/flake.lock"; then
    skip "unchanged"
  else
    ok "updated"
  fi
done

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
