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
              # CLI Utils - Modern CLI replacements
              bat # cat replacement
              bottom # top replacement
              delta # git diff viewer
              eza # ls replacement
              fd # find replacement
              fzf # fuzzy finder
              git # version control
              imagemagick # image manipulation
              ripgrep # grep replacement
              tree-sitter # parser library (used by neovim)
              yazi # file manager
              yt-dlp # video downloader
              xh # HTTP client
              fastfetch # fetch system information
              unzip # unzip utility

              # Shell Utils - Shell enhancements
              jq # JSON processor
              kanata # keyboard remapping
              starship # prompt
              tealdeer # tldr replacement
              zoxide # cd replacement

              # System Tools - Core system utilities
              coreutils-full # GNU Coreutils (full features)
              stow # dotfile manager

              # Languages - Programming languages
              cargo # Rust
              gcc # c, c++ compiler
              go # Go
              lua # Lua
              lua-language-server # Lua LSP
              lua53Packages.luarocks_bootstrap # Lua package manager
              nodejs # Node.js
              python3 # Python 3

              # Dev Tools - Development tools
              gh # GitHub CLI
              glow # markdown preview
              lazydocker # Docker UI
              lazygit # Git UI
              mermaid-cli # diagrams
              neovim-unwrapped # Editor
              static-web-server # Static server

              # DevOps/Infrastructure - Infrastructure tools
              google-cloud-sdk # GCP CLI
              opentofu # Terraform replacement (IaC)

              # Databases - Database clients
              mongosh # MongoDB CLI
              redli # Redis CLI

              # Presentations - Presentation tools
              presenterm # Markdown presentations
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
