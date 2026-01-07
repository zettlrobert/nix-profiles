{
  description = "Flake for `nebula` system packages";

  inputs = {
    # Latest stable Nixpkgs 0
    # Unstable Nixpkgs 0.1
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
    core.url = "path:../core-packages";
  };

  outputs = { self, nixpkgs, core }:
    let
      # Systems supported
      allSystems = [ "aarch64-linux" ];

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
          name = "nebula";
          paths = with pkgs; [
            # Custom Packages
            bat
            bottom
            coreutils-full
            delta
            eza
            fastfetch
            fd
            fzf
            go
            jq
            lazydocker
            lazygit
            mongosh
            starship
            tealdeer
            zoxide
            yazi
            stow
            atuin
          ];
        };
      });
    };
}
