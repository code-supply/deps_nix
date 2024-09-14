final: prev:

let
  apps = {
    explorer = [ "rustlerPrecompiled" ];
  };

  workarounds = {
    rustlerPrecompiled = old:
      let
        extendedPkgs = pkgs.extend fenixOverlay;
        fenixOverlay = import
          "${fetchTarball {
            url = "https://github.com/nix-community/fenix/archive/43efa7a3a97f290441bd75b18defcd4f7b8df220.tar.gz";
            sha256 = "sha256:1b9v45cafixpbj6iqjw3wr0yfpcrh3p11am7v0cjpjq5n8bhs8v3";
          }}/overlay.nix";
        nativeDir = "${old.src}/native/${old.packageName}";
        native = (extendedPkgs.makeRustPlatform {
          inherit (extendedPkgs.fenix.fromToolchainName {
            name = (extendedPkgs.lib.importTOML "${nativeDir}/rust-toolchain.toml").toolchain.channel;
            sha256 = "sha256-5icy5hSaQy6/fUim9L2vz2GeZNC3fX1N5T2MjnkTplc=";
          }) cargo rustc;
        }).buildRustPackage {
          pname = "${old.packageName}-native";
          version = old.version;
          src = nativeDir;
          cargoLock = {
            lockFile = "${nativeDir}/Cargo.lock";
          };
          nativeBuildInputs = [ extendedPkgs.cmake ];
          doCheck = false;
        };
        elixirConfig = extendedPkgs.writeTextDir "config/config.exs"
          ''
            import Config

            config :explorer, Explorer.PolarsBackend.Native,
              skip_compilation?: true
          '';
      in
      {
        nativeBuildInputs = [ extendedPkgs.cargo ];

        appConfigPath = "${elixirConfig}/config";

        env.RUSTLER_PRECOMPILED_FORCE_BUILD_ALL = "true";
        env.RUSTLER_PRECOMPILED_GLOBAL_CACHE_PATH = "unused-but-required";

        preConfigure = ''
          mkdir -p priv/native
          for lib in ${native}/lib/*
          do
            ln -s "$lib" "priv/native/$(basename "$lib")"
          done
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
