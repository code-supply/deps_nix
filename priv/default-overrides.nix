final: prev:

let
  apps = {
    ex_cldr_currencies = [ "cldrData" ];
    ex_cldr_numbers = [ "cldrData" ];
    grpcbox = [ "eponymousDir" ];
    png = [ "eponymousDir" ];
  };

  workarounds = {
    cldrData = { name, ... }: {
      preBuild = ''
        data_dir="$(mix eval --no-compile --no-deps-check "Cldr.Config.cldr_data_dir() |> IO.puts")"
        mkdir -p "$(dirname "$data_dir")"
        ln -sfv ${prev.ex_cldr}/src/priv/cldr "$(dirname "$data_dir")"
      '';
    };

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
