{
  description = "Flake for `midgard` system packages";

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
      # midgard is one x86_64 Linux workstation. llama-cpp-rocm, amdgpu_top,
      # ausweisapp and the Wayland tools are Linux-only in nixpkgs, and ROCm is
      # x86_64-only in practice, so other systems would fail to evaluate.
      allSystems = [ "x86_64-linux" ];

      # Helper to provide system-specific attributes
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs allSystems (
          system:
          f {
            pkgs = import nixpkgs {
              inherit system;
              config = {
                allowUnfree = true;
              };
              overlays = [
                # llama-cpp 0.4.1 builds its web UI (tools/ui) with nodejs_latest.
                # Node 26.9.0 fails its own test suite under Nix: test-fs-cp-async-file-modes
                # creates a setuid file, and Nix's filter-syscalls seccomp filter forbids that
                # by design. It fails on Hydra too, so nothing is cached and every machine must
                # build it locally and fail. See NixOS/nixpkgs#564449.
                # Node is build-time only here (no nodejs in llama-cpp's runtime closure),
                # so pinning the UI build to the cached nodejs_24 is safe.
                # Remove this overlay once #564449 is fixed and Node 26 is cached again.
                (final: prev: {
                  llama-cpp = prev.llama-cpp.override { nodejs_latest = final.nodejs_24; };
                })
              ];
            };
          }
        );
    in
    {
      packages = forAllSystems (
        { pkgs }: {
          default = pkgs.buildEnv {
            name = "midgard";
            paths = with pkgs; [
              core.packages.${pkgs.stdenv.hostPlatform.system}.default

              # Programming Languages
              # nodejs_24
              # (pnpm.override { nodejs = nodejs_24; })

              # GPU
              amdgpu_top

              # Wayland
              grim
              wl-clipboard

              # Local AI
              llama-cpp-rocm
              openai-whisper

              # Identification
              ausweisapp
            ];
          };
        }
      );
    };
}
