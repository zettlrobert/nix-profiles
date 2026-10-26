{
  description = "llama.cpp for local inference: a `default` build (CPU/Metal) and a `rocm` variant";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      allSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs allSystems (
          system:
          f {
            inherit system;
            # Note: config.rocmSupport is intentionally NOT set, so `default` is a
            # plain build. The rocm variant opts in explicitly via .override below.
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
      # One package, two variants (the "flag"): a profile picks
      #   llama-cpp.packages.${system}.default   # regular: CPU on Linux, Metal on macOS
      #   llama-cpp.packages.${system}.rocm       # AMD ROCm/HIP (x86_64-linux only)
      # Both ship bin/llama-server, so a profile installs exactly one.
      packages = forAllSystems (
        { system, pkgs }:
        {
          default = pkgs.llama-cpp;
        }
        # ROCm is x86_64-linux only in practice. Same build nixpkgs ships as
        # `llama-cpp-rocm` (llama-cpp.override { rocmSupport = true; }).
        # Tunables if needed:
        #   rocmGpuTargets = [ "gfx1100" ];   # pin the card's arch to cut build time
        #   nodejs_latest  = pkgs.nodejs_24;  # only if node 26 is not yet cached for the
        #                                     # pin (NixOS/nixpkgs#564449); build-time UI only
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          rocm = pkgs.llama-cpp.override { rocmSupport = true; };
        }
      );
    };
}
