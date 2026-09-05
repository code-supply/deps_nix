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
        let
          beamPackages = pkgs.beamMinimal29Packages.overrideScope (_: prev: { elixir = prev.elixir_1_20; });
        in
        (pkgs.callPackages ./fixtures/example/deps.nix { })
        // rec {
          example = pkgs.callPackage ./fixtures/example/package.nix { };
          default = deps_nix;
          deps_nix = pkgs.callPackage ./package.nix { inherit beamPackages; };
        }
      );

      devShells = forAllSystems (
        { pkgs, ... }:
        let
          beamPackages = pkgs.beamMinimal29Packages.overrideScope (_: prev: { elixir = prev.elixir_1_20; });
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
