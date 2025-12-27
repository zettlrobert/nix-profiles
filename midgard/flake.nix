{
  description = "Flake for `midgard` system packages";

  inputs = {
    # Latest stable Nixpkgs 0
    # Unstable Nixpkgs 0.1
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
    core.url = "path:../core-packages";
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
          name = "midgard";
          paths = with pkgs; [
            core.packages.${pkgs.system}.default

            # Custom Packages
            opentofu

            # Programming Languages
            # nodejs_24
            # (pnpm.override { nodejs = nodejs_24; })

            # GPU
            amdgpu_top

            # Wayland
            grim
            wl-clipboard
          ];
        };
      });
    };
}
