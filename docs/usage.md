# Usage

Everything below assumes Nix with flakes enabled (see [bootstrap.md](bootstrap.md)) and a working directory of this repo's root.

## Add a profile

```bash
nix profile add ./profiles/<host>
```

`<host>` is one of `fara`, `midgard`, `nebula`, `mac-mini`. This adds every package in the profile's `buildEnv` to your active Nix profile and links them into `~/.nix-profile/bin`.

## Add a single package

```bash
nix profile add ./packages/freecad-mcp
```

Anything under `packages/` is a flake that exposes `packages.${system}.default`. You can install one without pulling in a whole profile.

## Pin a specific revision

Profiles install from the current working tree by default. To pin a specific commit, point at the profile's subdirectory (the repo root has no `flake.nix`):

```bash
nix profile add "github:zettlrobert/nix-profiles?rev=<sha>&dir=profiles/<host>" --refresh
```

## List what's installed

```bash
nix profile list
```

Each entry has an **index** and a **store path**. Use the index (or the original flake URL) when upgrading or removing.

## Upgrade

Upgrade everything in the active profile:

```bash
nix profile upgrade --all
```

Upgrade only one entry (by index):

```bash
nix profile upgrade <index>
```

Important: `nix profile upgrade` re-resolves each flake input, but it does **not** bump the lockfiles in this repo. To pull a new nixpkgs revision into the profile, you have to update the locks first — see [Update the shared nixpkgs pin](#update-the-shared-nixpkgs-pin) below.

## Update the shared nixpkgs pin

All profiles follow `core/nixpkgs`, so updating core cascades everywhere on the next `nix flake update`. Core itself depends on `packages/freecad-mcp`, so the order is leaf first: `freecad-mcp`, then `core-packages`, then each profile. Updating a parent before its child locks the parent against the child's stale lock, and profiles end up on different nixpkgs revisions.

Shortcut, from the repo root with a clean git tree:

```bash
./update-flakes.sh          # updates all six locks in order and commits them
nix profile upgrade --all   # rebuild the active profile against the new locks
```

Pass `--no-commit` to stage the lock files without committing. The script refuses to run with uncommitted changes, because the lock would then reflect a `flake.nix` that is not in the commit.

By hand, same thing:

```bash
# 1. Bump the leaf package flake
nix flake update --flake ./packages/freecad-mcp

# 2. Bump core (picks up freecad-mcp's new lock)
nix flake update --flake ./packages/core-packages

# 3. Bump every profile (picks up core's new nixpkgs via nixpkgs.follows)
for p in profiles/*/; do nix flake update --flake "./$p"; done

# 4. Commit the locks so other machines see the same pin
git add '*/flake.lock'
git commit -m "chore: update nix flake locks"

# 5. Rebuild the active profile against the new lock
nix profile upgrade --all
```

Verify all locks agree on one nixpkgs revision:

```bash
grep -h '"rev"' */*/flake.lock | sort | uniq -c
```

One line in the output means every lock points at the same commit.

## Remove

By index (from `nix profile list`):

```bash
nix profile remove <index>
```

By flake URL (matches the entry's original source):

```bash
nix profile remove ./profiles/<host>
```

## Roll back

If an upgrade breaks something:

```bash
nix profile rollback                # back one generation
nix profile rollback --to <number>  # to a specific generation
nix profile history                 # list past generations
```

Generations are kept until you run `nix profile wipe-history` (or `nix store gc` removes their store paths).

## Garbage-collect old store paths

After upgrading, old derivations stay in `/nix/store` until collected:

```bash
nix store gc                   # delete anything not referenced by a live profile
nix profile wipe-history       # drop old profile generations first if you want them gone
```

## Switching to a different profile

Nix profiles are additive — installing a second profile does **not** remove the first. To swap profiles cleanly:

```bash
nix profile remove ./profiles/<old-host>
nix profile add ./profiles/<new-host>
```

Or wipe the whole active profile and start fresh:

```bash
nix profile remove --all
nix profile add ./profiles/<new-host>
```

## Gotchas

- **Unfree packages.** `allowUnfree = true` is set inside each flake's `import nixpkgs { ... }` call, so it works for everything in this repo without extra flags. If you add an unfree package from a flake that doesn't set this, you'll need `NIXPKGS_ALLOW_UNFREE=1` plus `--impure`.
- **PATH ordering on macOS.** `nix profile add` puts symlinks in `~/.nix-profile/bin`. Make sure that directory is *ahead of* `/usr/bin` in your shell rc so the Nix versions win.
- **Dirty git tree warnings.** When evaluating a flake from a working tree with uncommitted changes, Nix warns "Git tree ... has uncommitted changes." It's safe to ignore for local use; commit before pinning a revision for other machines.
- **First evaluation is slow.** Each flake fetches nixpkgs source on first use. Subsequent evals hit the local cache.

## Quick reference

| Goal | Command |
|---|---|
| Add a profile | `nix profile add ./profiles/<host>` |
| Add a single package | `nix profile add ./packages/<pkg>` |
| List installed | `nix profile list` |
| Upgrade all | `nix profile upgrade --all` |
| Bump every flake.lock and commit | `./update-flakes.sh` |
| Bump one flake's lock | `nix flake update --flake ./profiles/<host>` |
| Remove an entry | `nix profile remove <index>` |
| Roll back one generation | `nix profile rollback` |
| Garbage-collect | `nix store gc` |
