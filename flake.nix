{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      forAllSystems = generate: nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ]
        (system: generate ({ pkgs = nixpkgs.legacyPackages.${system}; }));
    in
    {
      packages = forAllSystems ({ pkgs, ... }: {
        fixture = pkgs.callPackages ./fixtures/example/deps.nix { };
      });

      devShells = forAllSystems ({ pkgs, ... }: {
        default = pkgs.callPackage ./shell.nix { };
      });
    };
}
