{
  description = "Nix flake for core packages";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"; };

  outputs = { self, nixpkgs }:
    let
      # Systems supported
      allSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];

      # Helper to provide system-specific attributes
      forAllSystems = f:
        nixpkgs.lib.genAttrs allSystems (system:
          f {
            pkgs = import nixpkgs {
              inherit system;
              config = { allowUnfree = true; };
            };
          });

      core = with nixpkgs.lib;
        let
          corePackages = pkgs:
            with pkgs; [
              # All core packages shared across systems
              bat
              bottom
              cargo
              coreutils-full
              delta
              eza
              fastfetch
              fd
              fzf
              gh
              glow
              go
              google-cloud-sdk
              imagemagick
              jq
              kanata
              lazydocker
              lazygit
              lua
              lua-language-server
              lua53Packages.luarocks_bootstrap
              mongosh
              neovim-unwrapped
              # https://exiftool.org/
              # perl538Packages.ImageExifTool
              presenterm
              redli
              static-web-server
              starship
              tealdeer
              tree-sitter
              yazi
              yt-dlp
              zoxide
              stow

              # Unfree
              # terraform
              # trunk-io
            ];
        in
        pkgs:
        pkgs.buildEnv {
          name = "core";
          paths = corePackages pkgs;
        };

    in
    { packages = forAllSystems ({ pkgs }: { default = core pkgs; }); };
}
