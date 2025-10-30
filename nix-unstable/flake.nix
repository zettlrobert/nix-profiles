{
  description = "Flake for `midgard` system packages";

  inputs = {
    # Latest stable Nixpkgs 0
    # Unstable Nixpkgs 0.1
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

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
        nixpkgs.lib.genAttrs allSystems
        (system: f { pkgs = import nixpkgs { inherit system; }; });
    in {
      packages = forAllSystems ({ pkgs }: {
        default = pkgs.buildEnv {
          name = "default";
          paths = with pkgs; [
            bottom
            delta
            eza
            fastfetch
            fd
            gh
            glow
            go
            google-cloud-sdk
            imagemagick
            kanata
            lazydocker
            lazygit
            lua
            lua-language-server
            lua53Packages.luarocks_bootstrap
            mongosh
            # https://exiftool.org/
            perl538Packages.ImageExifTool
            presenterm
            redli
            static-web-server
            tealdeer
            tree-sitter
            yazi
            yt-dlp
            zoxide

            # Unfree
            # terraform

            # TODO: Evaluate
            # aria2-1.37.0
            # cargo-1.82.0
            # cargo-c-0.10.2
            # httrack-3.49.2
            # https://www.infernojs.org/
            # inferno-0.11.21
            # neofetch-unstable-2021-12-10
            # r-treesitter-0.1.0
            # xone-0.3-unstable-2024-03-16

          ];
        };
      });
    };
}
