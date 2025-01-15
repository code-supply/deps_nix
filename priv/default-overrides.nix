final: prev:

let
  apps = {
    explorer = [
      {
        name = "rustlerPrecompiled";
        toolchain = {
          name = "nightly-2024-07-26";
          sha256 = "sha256-5icy5hSaQy6/fUim9L2vz2GeZNC3fX1N5T2MjnkTplc=";
        };
      }
    ];
  };

  applyOverrides =
    appName: drv:
    let
      allOverridesForApp = builtins.foldl' (
        acc: workaround: acc // (workarounds.${workaround.name} workaround) drv
      ) { } apps.${appName};

    in
    if builtins.hasAttr appName apps then drv.override allOverridesForApp else drv;

in
builtins.mapAttrs applyOverrides prev
