{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems =
        generate:
        nixpkgs.lib.genAttrs [
          "aarch64-darwin"
          "x86_64-darwin"
          "aarch64-linux"
          "x86_64-linux"
        ] (system: generate { pkgs = import nixpkgs { inherit system; }; });
    in
    {
      packages = forAllSystems (
        { pkgs, ... }:
        (pkgs.callPackages ./fixtures/example/deps.nix { })
        // {
          example = pkgs.callPackage ./fixtures/example/package.nix { };
        }
      );

      devShells = forAllSystems (
        { pkgs, ... }:
        let
          beamPackages = pkgs.beam28Packages.extend (_: prev: { elixir = prev.elixir_1_19; });
        in
        {
          default = pkgs.callPackage ./shells/local.nix { inherit beamPackages; };
          ci = pkgs.callPackage ./shells/ci.nix { inherit beamPackages; };
        }
      );

      checks = forAllSystems (
        { pkgs, ... }:
        {
          default = pkgs.linkFarmFromDrvs "fixtures" (
            builtins.attrValues self.packages.${pkgs.stdenv.hostPlatform.system}
          );
        }
      );
    };
}
