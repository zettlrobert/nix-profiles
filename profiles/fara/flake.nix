{
  description = "Flake for `fara` system packages";

  inputs = {
    core.url = "path:../../packages/core-packages";
    nixpkgs.follows = "core/nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      core,
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
            };
          }
        );
    in
    {
      packages = forAllSystems (
        { pkgs, system }: {
          default = pkgs.buildEnv {
            name = "fara";
            paths = with pkgs; [
              core.packages.${system}.default
              vim
              atuin
              syncthing

              # Programming Languages
              nodejs_24
              pnpm # pnpm 12 is a rust binary with its own bundled nodejs-slim, no nodejs override

              # Wayland
              grim
              wl-clipboard
            ];
          };
        }
      );
    };
}
