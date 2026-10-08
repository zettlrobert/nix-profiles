# Repository structure

## Top-level directories

| Path | Purpose |
|---|---|
| `packages/` | Anything that produces a derivation. One subdirectory per flake. |
| `profiles/` | Per-host `buildEnv` compositions. One subdirectory per host. |
| `docs/` | Documentation (this directory). |
| `update-flakes.sh` | Bumps every `flake.lock` leaf first and commits the result. See [usage.md](usage.md#update-the-shared-nixpkgs-pin). |

## packages/

Each subdirectory is its own flake exposing `packages.${system}.default`.

| Path | What it produces |
|---|---|
| `packages/core-packages` | A `buildEnv` aggregating the shared baseline CLI/dev tools every host needs. |
| `packages/freecad-mcp` | The `freecad-robust-mcp` Python package built from the upstream GitHub source. |

A package can be installed standalone (`nix profile add ./packages/<name>`) or pulled into a profile or another package as a flake input.

## profiles/

Each subdirectory is a host-specific flake. They share a common shape:

```nix
inputs = {
  core.url = "path:../../packages/core-packages";
  nixpkgs.follows = "core/nixpkgs";
};
```

The `nixpkgs.follows = "core/nixpkgs"` line is the important one: the profile has no nixpkgs pin of its own and reuses whatever `core-packages/flake.lock` has locked. The profile's own `flake.lock` still records that revision, so bumping core only reaches a profile when that profile runs `nix flake update` too. `update-flakes.sh` does this for all of them in the right order.

The `default` package in each profile is a `buildEnv` whose `paths` list starts with `core.packages.${system}.default` and then adds host-specific extras.

## Adding a new package

1. Create `packages/<name>/flake.nix` exposing `packages.${system}.default`.
2. To bundle it into core, add it as an input in `packages/core-packages/flake.nix`:
   ```nix
   inputs.<name>.url = "path:../<name>";
   inputs.<name>.inputs.nixpkgs.follows = "nixpkgs";
   ```
   then reference `inputs.<name>.packages.${system}.default` in the paths list.
3. To bundle it into a single profile instead, do the same in that profile's `flake.nix` with `path:../../packages/<name>`.
4. Add the new directory to `flake_dirs` in `update-flakes.sh`, before whatever depends on it. The script refuses to run until every `flake.nix` in the repo is listed.

## Adding a new profile

1. Create `profiles/<host>/flake.nix` with `core.url = "path:../../packages/core-packages"` and `nixpkgs.follows = "core/nixpkgs"`.
2. Compose `core.packages.${system}.default` plus host-specific extras in a `buildEnv`.
3. `nix flake update --flake ./profiles/<host> && nix profile add ./profiles/<host>`

Profiles are discovered by `update-flakes.sh` automatically, nothing to register.
