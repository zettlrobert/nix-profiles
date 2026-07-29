{
  description = "Flake for `fara` system packages";

  inputs = {
    core.url = "path:../../packages/core-packages";
    nixpkgs.follows = "core/nixpkgs";
  };

  outputs = { self, nixpkgs, core }:
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
    in
    {
      packages = forAllSystems ({ pkgs }: {
        default = pkgs.buildEnv {
          name = "fara";
          paths = with pkgs; [
            core.packages.${pkgs.stdenv.hostPlatform.system}.default
            vim
            atuin
            syncthing

            # Programming Languages
            nodejs_24
            (pnpm.override { nodejs = nodejs_24; })

            # Wayland
            grim
            wl-clipboard
          ];
        };
      });
    };
}
