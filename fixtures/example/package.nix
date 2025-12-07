{
  pkgs,
  ...
}:
let
  src = ./.;

  erlang = pkgs.beam.interpreters.erlang_28;
  beamUpstream = pkgs.beam.packagesWith erlang;
  elixir = beamUpstream.elixir_1_19;

  beamPackages = beamUpstream // rec {
    inherit erlang elixir;
    hex = beamUpstream.hex.override { inherit elixir; };
    buildMix = beamUpstream.buildMix.override { inherit elixir erlang hex; };
  };

  mixNixDeps = pkgs.callPackages ./deps.nix {
    beamPackages = beamPackages;
  };
in
beamPackages.buildMix {
  inherit
    src
    elixir
    ;

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
