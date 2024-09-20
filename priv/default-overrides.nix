final: prev:

let
  apps = {
    explorer = [ "rustlerPrecompiled" ];
    tokenizers = [ "rustlerPrecompiled" ];
  };

  elixirConfig = pkgs.writeTextDir "config/config.exs"
    ''
      import Config

      config :explorer, Explorer.PolarsBackend.Native,
        skip_compilation?: true

      config :tokenizers, Tokenizers.Native,
        skip_compilation?: true
    '';

  buildNativeDir = src: "${src}/native/${with builtins; head (attrNames (readDir "${src}/native"))}";

  workarounds = {
    rustlerPrecompiled = old:
      let
        extendedPkgs = pkgs.extend fenixOverlay;
        fenixOverlay = import
          "${fetchTarball {
            url = "https://github.com/nix-community/fenix/archive/43efa7a3a97f290441bd75b18defcd4f7b8df220.tar.gz";
            sha256 = "sha256:1b9v45cafixpbj6iqjw3wr0yfpcrh3p11am7v0cjpjq5n8bhs8v3";
          }}/overlay.nix";
        nativeDir = buildNativeDir old.src;
        rustToolchainPath = "${nativeDir}/rust-toolchain.toml";
        fenix =
          if builtins.pathExists rustToolchainPath
          then
            extendedPkgs.fenix.fromToolchainName
              {
                name = (extendedPkgs.lib.importTOML rustToolchainPath).toolchain.channel;
                sha256 = "sha256-5icy5hSaQy6/fUim9L2vz2GeZNC3fX1N5T2MjnkTplc=";
              }
          else
            extendedPkgs.fenix.stable;
        native = (extendedPkgs.makeRustPlatform {
          inherit (fenix) cargo rustc;
        }).buildRustPackage {
          pname = "${old.packageName}-native";
          version = old.version;
          src = nativeDir;
          cargoLock = {
            lockFile = "${nativeDir}/Cargo.lock";
          };
          nativeBuildInputs = [ extendedPkgs.cmake ] ++ extendedPkgs.lib.lists.optional extendedPkgs.stdenv.isDarwin extendedPkgs.darwin.IOKit;
          doCheck = false;
        };
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
