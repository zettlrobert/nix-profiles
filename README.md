# nix-profiles

Per-system package profiles built on a shared `core-packages` flake. All system flakes follow `core/nixpkgs` (nixpkgs-unstable), so there is a single nixpkgs pin to manage.

## Updating a system

```bash
# 1. Update the shared nixpkgs pin
cd core-packages
nix flake update

# 2. Update the system flake (picks up core's new pin)
cd ../<system>
nix flake update

# 3. Rebuild the profile
nix profile upgrade --all
```

Replace `<system>` with the target directory (e.g. `fara`, `midgard`, `nebula`).

## First-time install

```bash
cd <system>
nix profile install .
```
