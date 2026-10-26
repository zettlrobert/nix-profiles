{
  description = "Flake for `midgard` system packages";

  inputs = {
    core.url = "path:../../packages/core-packages";
    nixpkgs.follows = "core/nixpkgs";
    llama-cpp.url = "path:../../packages/llama-cpp";
    llama-cpp.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      core,
      llama-cpp,
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
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              config = {
                allowUnfree = true;
              };
              overlays = [ ];
            };
          }
        );
    in
    {
      packages = forAllSystems (
        { pkgs, system }: {
          default = pkgs.buildEnv {
            name = "midgard";
            paths = with pkgs; [
              core.packages.${system}.default

              # Programming Languages
              # nodejs_24
              # (pnpm.override { nodejs = nodejs_24; })

              # GPU
              amdgpu_top

              # Wayland
              grim
              wl-clipboard

              # Local AI
              llama-cpp.packages.${system}.rocm # AMD ROCm/HIP build (the `rocm` variant)
              openai-whisper
              pi-coding-agent

              # Document OCR
              ocrmypdf

              # Identification
              ausweisapp
            ];
          };
        }
      );
    };
}
