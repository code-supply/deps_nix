{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems =
        generate:
        nixpkgs.lib.genAttrs
          [
            "aarch64-darwin"
            "x86_64-darwin"
            "aarch64-linux"
            "x86_64-linux"
          ]
          (
            system:
            generate {
              pkgs = import nixpkgs {
                inherit system;
                overlays = [
                  (
                    self: super:
                    let
                      beamPackages = with super.beam_minimal; packagesWith interpreters.erlang_27;
                    in
                    {
                      inherit beamPackages;
                      erlang = beamPackages.erlang_27;
                      elixir = beamPackages.elixir_1_17;
                    }
                  )
                ];
              };
            }
          );
    in
    {
      packages = forAllSystems ({ pkgs, ... }: (pkgs.callPackages ./fixtures/example/deps.nix { }));

      devShells = forAllSystems (
        { pkgs, ... }:
        {
          default = pkgs.callPackage ./shells/local.nix { };
          ci = pkgs.callPackage ./shells/ci.nix { };
        }
      );

      checks = forAllSystems (
        { pkgs, ... }:
        {
          default = pkgs.linkFarmFromDrvs "fixtures" (builtins.attrValues self.packages.${pkgs.system});
        }
      );
    };
}
