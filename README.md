# nix-profiles

Per-host package profiles for non-NixOS systems, built on a shared `core-packages` flake. All profiles follow `core/nixpkgs` (nixpkgs-unstable), so there is a single nixpkgs pin to manage.

## Layout

```
nix-profiles/
├── docs/                          # bootstrap and structure notes
├── packages/
│   ├── core-packages/             # shared base, every profile pulls this in
│   └── freecad-mcp/               # standalone installable flake
└── profiles/
    ├── fara/                      # workstation profile
    ├── midgard/                   # workstation profile (AMD GPU, local AI)
    ├── nebula/                    # minimal aarch64 profile
    └── mac-mini/                  # macOS profile
```

`packages/` holds anything that produces a derivation. `profiles/` holds per-host `buildEnv` compositions that consume one or more packages.

## Updating a system

```bash
# 1. Update the shared nixpkgs pin
cd packages/core-packages
nix flake update

# 2. Update the profile (picks up core's new pin via `nixpkgs.follows`)
cd ../../profiles/<host>
nix flake update

# 3. Rebuild the active profile
nix profile upgrade --all
```

Replace `<host>` with the target directory (e.g. `fara`, `midgard`, `nebula`, `mac-mini`).

## First-time install

Whole profile:

```bash
cd profiles/<host>
nix profile install .
```

Just one packaged tool, no profile:

```bash
nix profile install ./packages/freecad-mcp
```
