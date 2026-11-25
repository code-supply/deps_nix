{
  pkgs,
  ...
}:
let
  beamPackages = pkgs.beamMinimal28Packages.overrideScope (_: prev: { elixir = prev.elixir_1_19; });
in
beamPackages.mixRelease {
  pname = "example";
  version = "0.1.0";
  src = ./.;

  mixNixDeps = pkgs.callPackages ./deps.nix {
    inherit beamPackages;
  };

  nativeBuildInputs = [ pkgs.rustPackages.cargo ];

  mixEnv = "test";
  doCheck = true;

  checkPhase = ''
    mix test --no-deps-check
  '';
}
