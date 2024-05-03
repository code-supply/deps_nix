final: prev:

let
  apps = { };

  workarounds = { };

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
