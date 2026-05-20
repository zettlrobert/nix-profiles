# Repository structure

## Top-level directories

| Path | Purpose |
|---|---|
| `packages/` | Anything that produces a derivation. One subdirectory per flake. |
| `profiles/` | Per-host `buildEnv` compositions. One subdirectory per host. |
| `docs/` | Documentation (this directory). |

## packages/

Each subdirectory is its own flake exposing `packages.${system}.default`.

| Path | What it produces |
|---|---|
| `packages/core-packages` | A `buildEnv` aggregating the shared baseline CLI/dev tools every host needs. |
| `packages/freecad-mcp` | The `freecad-robust-mcp` Python package built from the upstream GitHub source. |

A package can be installed standalone (`nix profile install ./packages/<name>`) or pulled into a profile or another package as a flake input.

## profiles/

Each subdirectory is a host-specific flake. They share a common shape:

```nix
inputs = {
  core.url = "path:../../packages/core-packages";
  nixpkgs.follows = "core/nixpkgs";
};
```

The `nixpkgs.follows = "core/nixpkgs"` line is the important one: it pins the profile's `nixpkgs` to whatever revision `core-packages/flake.lock` has locked, so every profile sees the same nixpkgs commit. Bumping `packages/core-packages` cascades to all profiles on their next `nix flake update`.

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

## Adding a new profile

1. Create `profiles/<host>/flake.nix` with `core.url = "path:../../packages/core-packages"` and `nixpkgs.follows = "core/nixpkgs"`.
2. Compose `core.packages.${system}.default` plus host-specific extras in a `buildEnv`.
3. `cd profiles/<host> && nix flake update && nix profile install .`
