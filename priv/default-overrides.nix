final: prev:

let
  apps = {
    grpcbox = [ "eponymousDir" ];
    png = [ "eponymousDir" ];
  };

  workarounds = {
    eponymousDir = { name, ... }: {
      unpackPhase = ''
        runHook preUnpack
        unpackFile "$src"
        chmod -R u+w -- hex-source-${name}
        mv hex-source-${name} ${name}
        sourceRoot=${name}
        runHook postUnpack
      '';
    };
  };

  applyOverrides = appName: drv:
    let
      allOverridesForApp = builtins.foldl'
        (acc: workaround: acc // workarounds.${workaround} drv)
        { }
        apps.${appName};

    in
    if builtins.hasAttr appName apps
    then
      drv.override allOverridesForApp
    else
      drv;

in
builtins.mapAttrs applyOverrides prev
