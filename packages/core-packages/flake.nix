{
  description = "Nix flake for core packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    freecad-mcp.url = "path:../freecad-mcp";
    freecad-mcp.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      freecad-mcp,
    }:
    let
      # Systems supported
      allSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];

      # Helper to provide system-specific attributes
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs allSystems (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              config = {
                allowUnfree = true;
              };
              overlays = [ easyeffectsOverlay ];
            };
          }
        );

      # easyeffects is Qt Quick and needs a GL context. On a non-NixOS host there is no
      # /run/opengl-driver, so the Nix Qt build finds no EGL and aborts with
      # "Failed to initialize graphics backend for OpenGL" before the window ever opens.
      # The software scenegraph costs nothing for a mixer UI and the DSP is untouched.
      #
      # xdgdesktopportal is what gets dark mode: kdeglobals on midgard sets
      # widgetStyle=qt6ct-style, which is not in this closure, so the style load fails and
      # Qt falls back to its light default. The portal reports the desktop preference instead.
      #
      # Linux only. Guarded at the call site, and lazy here, so darwin never evaluates it.
      easyeffectsOverlay = final: prev: {
        easyeffects = final.symlinkJoin {
          name = "easyeffects-wrapped-${prev.easyeffects.version}";
          paths = [ prev.easyeffects ];
          nativeBuildInputs = [ final.makeWrapper ];
          postBuild = ''
            rm "$out/bin/easyeffects"
            makeWrapper "${prev.easyeffects}/bin/easyeffects" "$out/bin/easyeffects" \
              --set QT_QUICK_BACKEND software \
              --set QT_QPA_PLATFORMTHEME xdgdesktopportal
          '';
        };
      };

      corePackages =
        pkgs: system:
        with pkgs;
        [
          # All core packages shared across systems
          # CLI Utils - Modern CLI replacements
          bat # cat replacement
          bottom # top replacement
          delta # git diff viewer
          eza # ls replacement
          fd # find replacement
          fzf # fuzzy finder
          git # version control
          git-lfs # git large file storage
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
          herdr # AI Multiplexer
          crush # AI coding agent in the terminal (Charm)

          # System Tools - Core system utilities
          coreutils-full # GNU Coreutils (full features)
          stow # dotfile manager
          kopia # backup tool
          wakeonlan # send Wake-on-LAN magic packets (UDP, no root)
          android-tools # adb + fastboot for phones and emulators

          # Languages - Programming languages
          cargo # Rust
          gcc # c, c++ compiler
          go # Go
          pkgsite # local pkg.go.dev docs server for Go modules
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
          vale # prose linter (driven by vale-ls in nvim)

          # DevOps/Infrastructure - Infrastructure tools
          google-cloud-sdk # GCP CLI
          opentofu # Terraform replacement (IaC)
          awscli2 # AWS CLI v2 - S3 API against SeaweedFS/MinIO, etc.

          # Databases - Database clients
          mongosh # MongoDB CLI
          redli # Redis CLI

          # Presentations - Presentation tools
          presenterm # Markdown presentations
          python3Packages.pylatexenc # provides `latex2text` for render-markdown LaTeX rendering

          # AI / MCP Tools
          freecad-mcp.packages.${system}.default # FreeCAD MCP client
        ]
        ++ lib.optionals stdenv.hostPlatform.isLinux [
          # Audio
          # Replaces the flatpak. PipeWire only, so it is excluded on darwin
          # (the mac mini); nixpkgs marks it platforms.linux and it would not build.
          # Presets and the db/ settings live in ~/.config/easyeffects, stowed from the
          # configurations repo, so the EQ, convolver and mic chain follow the host.
          # Wrapped by easyeffectsOverlay above for OpenGL and dark mode.
          easyeffects
        ];

      core =
        pkgs: system:
        pkgs.buildEnv {
          name = "core";
          paths = corePackages pkgs system;
        };
    in
    {
      packages = forAllSystems (
        { pkgs, system }:
        {
          default = core pkgs system;
        }
      );

      # `nix run ./packages/core-packages#formatter.<system>` from the repo root
      # formats every flake.nix in the tree with the official nixfmt.
      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt-tree);
    };
}
