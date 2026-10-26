{
  description = "Flake for `midgard` system packages";

  inputs = {
    core.url = "path:../../packages/core-packages";
    nixpkgs.follows = "core/nixpkgs";
    llama-cpp.url = "path:../../packages/llama-cpp";
    llama-cpp.inputs.nixpkgs.follows = "nixpkgs";
    # FreeCAD MCP is workstation-only, so it is a midgard input here rather than
    # in the shared core-packages (servers and the mac do not need it).
    freecad-mcp.url = "path:../../packages/freecad-mcp";
    freecad-mcp.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      core,
      llama-cpp,
      freecad-mcp,
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

              # CAD / MCP
              freecad-mcp.packages.${system}.default # FreeCAD MCP client (moved off core-packages)

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
