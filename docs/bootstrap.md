# Bootstrapping a non-NixOS host

This repo is designed for non-NixOS systems where Nix is installed as a side-by-side package manager and tools are managed through `nix profile`.

## 1. Install Nix

Determinate's installer is recommended on Linux and macOS:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Enable flakes (Determinate enables them by default). For manual installs, ensure `~/.config/nix/nix.conf` contains:

```
experimental-features = nix-command flakes
```

## 2. Clone this repo

```bash
git clone https://github.com/zettlrobert/nix-profiles.git ~/repositories/github.com/zettlrobert/nix-profiles
cd ~/repositories/github.com/zettlrobert/nix-profiles
```

## 3. Add the profile for your host

```bash
cd profiles/<host>
nix profile add .
```

Pick the directory matching your machine (`fara`, `midgard`, `nebula`, `mac-mini`) or create a new one (see `structure.md`).

## 4. Dotfiles

This repo only handles installed binaries. Dotfiles live in [`zettlrobert/configurations`](https://github.com/zettlrobert/configurations) and are managed with GNU Stow. Clone that repo and stow the packages you need:

```bash
git clone https://github.com/zettlrobert/configurations.git
cd configurations/dotfiles
stow git zsh starship lazygit  # etc.
```

## 5. Keeping things up to date

```bash
# from anywhere inside this repo
cd packages/core-packages && nix flake update
cd ../../profiles/<host>  && nix flake update
nix profile upgrade --all
```
