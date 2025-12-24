{
  pkgs,
  ...
}:
let
  src = ./.;

  beamPackages = pkgs.beamMinimal28Packages.extend (_: prev: { elixir = prev.elixir_1_19; });

  mixNixDeps = pkgs.callPackages ./deps.nix {
    beamPackages = beamPackages;
  };
in
beamPackages.buildMix {
  inherit src;

  name = "example";
  version = "0.1.0";
  mixEnv = "test";
  doCheck = true;

  nativeBuildInputs = [
    pkgs.rustPackages.cargo
    (builtins.attrValues mixNixDeps)
  ];

  checkPhase = ''
    mix test --no-deps-check
  '';
}
