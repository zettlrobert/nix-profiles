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
      # fara is one x86_64 Linux workstation.
      allSystems = [ "x86_64-linux" ];

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
            ];
          };
        }
      );
    };
}
