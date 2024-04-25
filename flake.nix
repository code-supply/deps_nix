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
        (system: generate (
          let
            pkgs = nixpkgs.legacyPackages.${system};
            callPackage = pkgs.lib.callPackageWith pkgs;
          in
          {
            inherit pkgs callPackage;
          }
        ));
    in
    {
      packages = forAllSystems ({ pkgs, ... }: {
        fixture = pkgs.callPackages ./fixtures/example/deps.nix { };
      });

      devShells = forAllSystems ({ callPackage, ... }: {
        default = callPackage ./shell.nix { };
      });
    };
}
