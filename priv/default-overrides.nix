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
    tokenizers = [
      {
        name = "rustlerPrecompiled";
      }
    ];
  };

  elixirConfig = pkgs.writeTextDir
    "config/config.exs"
    ''
      import Config

      config :explorer, Explorer.PolarsBackend.Native,
        skip_compilation?: true

      config :tokenizers, Tokenizers.Native,
        skip_compilation?: true
    '';

  buildNativeDir = src: "${src}/native/${with builtins; head (attrNames (readDir "${src}/native"))}";

  workarounds = {
    rustlerPrecompiled = { toolchain ? null, ... }: old:
      let
        extendedPkgs = pkgs.extend fenixOverlay;
        fenixOverlay = import
          "${fetchTarball {
            url = "https://github.com/nix-community/fenix/archive/280efe0e9b7b824518091a5aff76065785f81649.tar.gz";
            sha256 = "sha256:07qi34kbz9hyxp0cjh2r37ix0jc849rd5c9cxw1ad3l4r92f4fcg";
          }}/overlay.nix";
        nativeDir = buildNativeDir old.src;
        fenix =
          if toolchain == null
          then extendedPkgs.fenix.stable
          else extendedPkgs.fenix.fromToolchainName toolchain;
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
        (acc: workaround: acc // (workarounds.${workaround.name} workaround) drv)
        { }
        apps.${appName};

    in
    if builtins.hasAttr appName apps
    then
      drv.override allOverridesForApp
    else
      drv;

in
builtins.mapAttrs
  applyOverrides
  prev
