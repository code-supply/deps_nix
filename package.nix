{
  beamPackages,
  callPackages,
  gnutar,
  lib,
}:
let
  version = lib.trim (builtins.readFile ./VERSION);
in
beamPackages.mixRelease (finalAttrs: {
  pname = "deps_nix";
  inherit version;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./lib
      ./mix.exs
      ./mix.lock
      ./VERSION
    ];
  };

  mixNixDeps = callPackages ./deps.nix {
    inherit lib beamPackages;
  };

  escriptBinName = "deps_nix";

  postFixup = ''
    wrapProgram $out/bin/deps_nix \
      --suffix ERL_LIBS : ${beamPackages.hex}/lib/erlang/lib \
      --suffix PATH : ${lib.makeBinPath [ gnutar ]}
  '';

  meta = {
    description = "escript that converts Mix dependencies to Nix derivations";
    homepage = "https://github.com/code-supply/deps_nix";
    changelog = "https://github.com/code-supply/deps_nix/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "deps_nix";
  };
})
