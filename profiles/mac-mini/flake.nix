{
  description = "Flake for `mac-mini` system packages";

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
      # mac-mini is one Apple Silicon Mac. nixpkgs 26.11 dropped x86_64-darwin.
      allSystems = [ "aarch64-darwin" ];

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
            name = "mac-mini";
            paths = with pkgs; [
              core.packages.${system}.default

              # macOS-specific extras
              # https://exiftool.org/
              perlPackages.ImageExifTool
            ];
          };
        }
      );
    };
}
