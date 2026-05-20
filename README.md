# nix-profiles

Per-host package profiles for non-NixOS systems, built on a shared `core-packages` flake. All profiles follow `core/nixpkgs` (nixpkgs-unstable), so there is a single nixpkgs pin to manage.

## Layout

```
nix-profiles/
├── docs/                          # bootstrap, structure, usage
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

## Quick start

Add a profile:

```bash
nix profile add ./profiles/<host>
```

Add a single package (no profile):

```bash
nix profile add ./packages/freecad-mcp
```

Update everything:

```bash
cd packages/core-packages && nix flake update
cd ../../profiles/<host>  && nix flake update
nix profile upgrade --all
```

## Documentation

- [docs/bootstrap.md](docs/bootstrap.md) — installing Nix and getting the repo onto a new machine
- [docs/usage.md](docs/usage.md) — full `nix profile` command reference (add, upgrade, remove, rollback, gc)
- [docs/workflow.md](docs/workflow.md) — day-to-day patterns: flake refs, trying tools, multiple profiles, conflicts
- [docs/structure.md](docs/structure.md) — how packages and profiles are wired together; how to add new ones
