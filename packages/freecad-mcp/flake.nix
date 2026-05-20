{
  description = "Robust MCP server for FreeCAD integration";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"; };

  outputs = { self, nixpkgs }:
    let
      allSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

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
        default = pkgs.python3Packages.buildPythonPackage {
          pname = "freecad-robust-mcp";
          version = "0.6.1";
          pyproject = true;

          src = pkgs.fetchFromGitHub {
            owner = "spkane";
            repo = "freecad-addon-robust-mcp-server";
            rev = "robust-mcp-server-v0.6.1";
            hash = "sha256-qaH5qA5OQrIS+xYphgVq3KqiX7MZOvSYZ3dfcOCSREg=";
          };

          nativeBuildInputs = with pkgs.python3Packages; [ hatchling hatch-vcs ];
          dependencies = with pkgs.python3Packages; [ mcp pydantic pydantic-settings ];
          doCheck = false;

          meta = {
            description = "Robust MCP Server for FreeCAD integration";
            license = pkgs.lib.licenses.mit;
          };
        };
      });
    };
}
