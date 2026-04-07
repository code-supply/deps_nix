{
  lib,
  beamPackages,
  cmake,
  extend,
  lexbor,
  fetchFromGitHub,
  oniguruma,
  overrides ? (x: y: { }),
  overrideFenixOverlay ? null,
  rustlerPrecompiledOverrides ? { },
  stdenv,
  pkg-config,
  vips,
  writeText,
}:

let
  buildMix = lib.makeOverridable beamPackages.buildMix;
  buildRebar3 = lib.makeOverridable beamPackages.buildRebar3;

  workarounds = {
    portCompiler = _unusedArgs: old: {
      buildPlugins = [ beamPackages.pc ];
    };

    rustlerPrecompiled =
      {
        toolchain ? null,
        buildInputs ? [ ],
        nativeBuildInputs ? [ ],
        env ? { },
        ...
      }:
      old:
      let
        extendedPkgs = extend fenixOverlay;
        fenixOverlay =
          if overrideFenixOverlay == null then
            import "${
              fetchTarball {
                url = "https://github.com/nix-community/fenix/archive/6399553b7a300c77e7f07342904eb696a5b6bf9d.tar.gz";
                sha256 = "sha256-C6tT7K1Lx6VsYw1BY5S3OavtapUvEnDQtmQB5DSgbCc=";
              }
            }/overlay.nix"
          else
            overrideFenixOverlay;
        nativeDir = "${old.src}/native/${with builtins; head (attrNames (readDir "${old.src}/native"))}";
        fenix =
          if toolchain == null then
            extendedPkgs.fenix.stable
          else
            extendedPkgs.fenix.fromToolchainName toolchain;
        native =
          (
            (extendedPkgs.makeRustPlatform {
              inherit (fenix) cargo rustc;
            }).buildRustPackage
            {
              inherit env buildInputs;
              pname = "${old.beamModuleName}-native";
              version = old.version;
              src = nativeDir;
              cargoLock = {
                lockFile = "${nativeDir}/Cargo.lock";
              };
              nativeBuildInputs = [ extendedPkgs.cmake ] ++ nativeBuildInputs;
              doCheck = false;
            }
          ).overrideAttrs
            rustlerPrecompiledOverrides.${old.beamModuleName} or { };

      in
      {
        nativeBuildInputs = [ extendedPkgs.cargo ];

        env.RUSTLER_PRECOMPILED_FORCE_BUILD_ALL = "true";
        env.RUSTLER_PRECOMPILED_GLOBAL_CACHE_PATH = "unused-but-required";

        preConfigure = ''
          mkdir -p priv/native
          for lib in ${native}/lib/*
          do
            dest="$(basename "$lib")"
            if [[ "''${dest##*.}" = "dylib" ]]
            then
              dest="''${dest%.dylib}.so"
            fi
            ln -s "$lib" "priv/native/$dest"
          done
        '';

        preBuild = ''
          suggestion() {
            echo "***********************************************"
            echo "                 deps_nix                      "
            echo
            echo " Rust dependency build failed.                 "
            echo
            echo " If you saw network errors, you might need     "
            echo " to disable compilation on the appropriate     "
            echo " RustlerPrecompiled module in your             "
            echo " application config.                           "
            echo
            echo " We think you need this:                       "
            echo
            echo -n " "
            grep -Rl 'use RustlerPrecompiled' lib \
              | xargs grep 'defmodule' \
              | sed 's/defmodule \(.*\) do/config :${old.beamModuleName}, \1, skip_compilation?: true/'
            echo "***********************************************"
            exit 1
          }
          trap suggestion ERR
        '';
      };

    elixirMake = _unusedArgs: old: {
      preConfigure = ''
        export ELIXIR_MAKE_CACHE_DIR="$TEMPDIR/elixir_make_cache"
      '';
    };

    lazyHtml = _unusedArgs: old: {
      preConfigure = ''
        export ELIXIR_MAKE_CACHE_DIR="$TEMPDIR/elixir_make_cache"
      '';

      postPatch = ''
        substituteInPlace mix.exs \
          --replace-fail "Fine.include_dir()" '"${packages.fine}/src/c_include"' \
          --replace-fail '@lexbor_git_sha "244b84956a6dc7eec293781d051354f351274c46"' '@lexbor_git_sha ""'
      '';

      preBuild = ''
        install -Dm644           -t _build/c/third_party/lexbor/$LEXBOR_GIT_SHA/build           ${lexbor}/lib/liblexbor_static.a
      '';
    };
  };

  defaultOverrides = (
    final: prev:

    let
      apps = {
        crc32cer = [
          {
            name = "portCompiler";
          }
        ];
        explorer = [
          {
            name = "rustlerPrecompiled";
            toolchain = {
              name = "nightly-2025-06-23";
              sha256 = "sha256-UAoZcxg3iWtS+2n8TFNfANFt/GmkuOMDf7QAE0fRxeA=";
            };
          }
        ];
        snappyer = [
          {
            name = "portCompiler";
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
  );

  self = packages // (defaultOverrides self packages) // (overrides self packages);

  packages =
    with beamPackages;
    with self;
    {

      acceptor_pool =
        let
          version = "1.0.1";
          drv = buildRebar3 {
            inherit version;
            name = "acceptor_pool";

            src = fetchHex {
              inherit version;
              pkg = "acceptor_pool";
              sha256 = "f172f3d74513e8edd445c257d596fc84dbdd56d2c6fa287434269648ae5a421e";
            };
          };
        in
        drv;

      aws_signature =
        let
          version = "0.4.2";
          drv = buildRebar3 {
            inherit version;
            name = "aws_signature";

            src = fetchHex {
              inherit version;
              pkg = "aws_signature";
              sha256 = "1df4a2d1dff200c7bdfa8f9f935efc71a51273adfc6dd39a9f2cc937e01baa01";
            };
          };
        in
        drv;

      bandit =
        let
          version = "1.4.2";
          drv = buildMix {
            inherit version;
            name = "bandit";
            appConfigPath = ./config;

            src = fetchFromGitHub {
              owner = "mtrudel";
              repo = "bandit";
              rev = "4f15f029e7aa17f8e7f98d55b0e94c684dee0971";
              hash = "sha256-xYwyAchzICt4gcz6PplMlre1blNDuSqfF6Lr0cXM0kU=";
            };

            beamDeps = [
              thousand_island
              plug
              websock
              hpax
              telemetry
            ];
          };
        in
        drv;

      brod =
        let
          version = "3.19.1";
          drv = buildRebar3 {
            inherit version;
            name = "brod";

            src = fetchHex {
              inherit version;
              pkg = "brod";
              sha256 = "241899cff62e175cd60de4acd4b72f40edb3529b18853f8b22a8a35e4c76d71d";
            };

            beamDeps = [
              kafka_protocol
              snappyer
            ];
          };
        in
        drv;

      castore =
        let
          version = "1.0.18";
          drv = buildMix {
            inherit version;
            name = "castore";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "castore";
              sha256 = "f393e4fe6317829b158fb74d86eb681f737d2fe326aa61ccf6293c4104957e34";
            };
          };
        in
        drv;

      cc_precompiler =
        let
          version = "0.1.11";
          drv = buildMix {
            inherit version;
            name = "cc_precompiler";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "cc_precompiler";
              sha256 = "3427232caf0835f94680e5bcf082408a70b48ad68a5f5c0b02a3bea9f3a075b9";
            };

            beamDeps = [
              elixir_make
            ];
          };
        in
        drv.override (workarounds.elixirMake { } drv);

      chatterbox =
        let
          version = "0.15.1";
          drv = buildRebar3 {
            inherit version;
            name = "chatterbox";

            src = fetchHex {
              inherit version;
              pkg = "ts_chatterbox";
              sha256 = "4f75b91451338bc0da5f52f3480fa6ef6e3a2aeecfc33686d6b3d0a0948f31aa";
            };

            beamDeps = [
              hpack
            ];
          };
        in
        drv;

      cldr_utils =
        let
          version = "2.29.5";
          drv = buildMix {
            inherit version;
            name = "cldr_utils";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "cldr_utils";
              sha256 = "962d3a2028b232ee0a5373941dc411028a9442f53444a4d5d2c354f687db1835";
            };

            beamDeps = [
              castore
              decimal
            ];
          };
        in
        drv;

      crc32cer =
        let
          version = "0.1.8";
          drv = buildRebar3 {
            inherit version;
            name = "crc32cer";

            src = fetchHex {
              inherit version;
              pkg = "crc32cer";
              sha256 = "251499085482920deb6c9b7aadabf9fb4c432f96add97ab42aee4501e5b6f591";
            };
          };
        in
        drv;

      ctx =
        let
          version = "0.6.0";
          drv = buildRebar3 {
            inherit version;
            name = "ctx";

            src = fetchHex {
              inherit version;
              pkg = "ctx";
              sha256 = "a14ed2d1b67723dbebbe423b28d7615eb0bdcba6ff28f2d1f1b0a7e1d4aa5fc2";
            };
          };
        in
        drv;

      db_connection =
        let
          version = "2.9.0";
          drv = buildMix {
            inherit version;
            name = "db_connection";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "db_connection";
              sha256 = "17d502eacaf61829db98facf6f20808ed33da6ccf495354a41e64fe42f9c509c";
            };

            beamDeps = [
              telemetry
            ];
          };
        in
        drv;

      decimal =
        let
          version = "2.3.0";
          drv = buildMix {
            inherit version;
            name = "decimal";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "decimal";
              sha256 = "a4d66355cb29cb47c3cf30e71329e58361cfcb37c34235ef3bf1d7bf3773aeac";
            };
          };
        in
        drv;

      digital_token =
        let
          version = "1.0.0";
          drv = buildMix {
            inherit version;
            name = "digital_token";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "digital_token";
              sha256 = "8ed6f5a8c2fa7b07147b9963db506a1b4c7475d9afca6492136535b064c9e9e6";
            };

            beamDeps = [
              cldr_utils
              jason
            ];
          };
        in
        drv;

      elixir_make =
        let
          version = "0.9.0";
          drv = buildMix {
            inherit version;
            name = "elixir_make";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "elixir_make";
              sha256 = "db23d4fd8b757462ad02f8aa73431a426fe6671c80b200d9710caf3d1dd0ffdb";
            };
          };
        in
        drv;

      eventstore =
        let
          version = "1.4.8";
          drv = buildMix {
            inherit version;
            name = "eventstore";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "eventstore";
              sha256 = "30c914602fdea8db5992a90ecb1f84068531e764cf0c066be71ff0eec4e3bcb9";
            };

            beamDeps = [
              fsm
              gen_stage
              jason
              postgrex
            ];
          };
        in
        drv;

      ex_cldr =
        let
          version = "2.47.2";
          drv = buildMix {
            inherit version;
            name = "ex_cldr";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr";
              sha256 = "4a7cef380a1c2546166b45d6ee5e8e2f707ea695b12ae6dadd250201588b4f16";
            };

            beamDeps = [
              cldr_utils
              decimal
              jason
              nimble_parsec
            ];
          };
        in
        drv;

      ex_cldr_calendars =
        let
          version = "2.4.2";
          drv = buildMix {
            inherit version;
            name = "ex_cldr_calendars";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr_calendars";
              sha256 = "ab69fd04bc1ae18baf9d2e57335d4754c5ac263076ea397eb112621702251fe5";
            };

            beamDeps = [
              ex_cldr_numbers
              jason
            ];
          };
        in
        drv;

      ex_cldr_currencies =
        let
          version = "2.17.1";
          drv = buildMix {
            inherit version;
            name = "ex_cldr_currencies";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr_currencies";
              sha256 = "e266a0a61f4c7d83608154d49b59e4d7485b2aaa7ba1d0e17b3c55910595de51";
            };

            beamDeps = [
              ex_cldr
              jason
            ];
          };
        in
        drv;

      ex_cldr_dates_times =
        let
          version = "2.25.6";
          drv = buildMix {
            inherit version;
            name = "ex_cldr_dates_times";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr_dates_times";
              sha256 = "926ff5662b849f86088832ee66b61a96aab0fa5a54d5e14240e08ad3030663e2";
            };

            beamDeps = [
              ex_cldr_calendars
              jason
            ];
          };
        in
        drv;

      ex_cldr_numbers =
        let
          version = "2.38.1";
          drv = buildMix {
            inherit version;
            name = "ex_cldr_numbers";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr_numbers";
              sha256 = "4f95738f1dc4e821485e52226666f7691c9276bf6eba49cba8d23c8a2db05e84";
            };

            beamDeps = [
              decimal
              digital_token
              ex_cldr
              ex_cldr_currencies
              jason
            ];
          };
        in
        drv;

      ex_heroicons =
        let
          version = "3.1.0";
          drv = buildMix {
            inherit version;
            name = "ex_heroicons";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_heroicons";
              sha256 = "e37d0270b429d292a652efc477fe4c80a245d5ac9f8e3d879c6c653dab30835c";
            };

            beamDeps = [
              phoenix_live_view
            ];
          };
        in
        drv.override {
          preBuild = ''
            mkdir deps
            ln -sfv ${heroicons} deps/heroicons
          '';
        };

      ex_keccak =
        let
          version = "0.7.8";
          drv = buildMix {
            inherit version;
            name = "ex_keccak";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_keccak";
              sha256 = "52de5b42b718df2534fb9a55780d8a05bbaea539f867c3e7c0a8e7e1d5f149d9";
            };

            beamDeps = [
              rustler
              rustler_precompiled
            ];
          };
        in
        drv.override (workarounds.rustlerPrecompiled { } drv);

      ex_secp256k1 =
        let
          version = "0.7.6";
          drv = buildMix {
            inherit version;
            name = "ex_secp256k1";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_secp256k1";
              sha256 = "b84c9c4d85b47410cd951222b4d2b644cdbff96f4f83bc5ac96ee15d850a113c";
            };

            beamDeps = [
              rustler
              rustler_precompiled
            ];
          };
        in
        drv.override (workarounds.rustlerPrecompiled { } drv);

      explorer =
        let
          version = "0.11.1";
          drv = buildMix {
            inherit version;
            name = "explorer";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "explorer";
              sha256 = "acc679ea15790d03d9a406bb45284bd4e30531d01a650d9194393cbadcdefccd";
            };

            beamDeps = [
              aws_signature
              decimal
              fss
              rustler
              rustler_precompiled
              table
              table_rex
            ];
          };
        in
        drv.override (workarounds.rustlerPrecompiled { } drv);

      fine =
        let
          version = "0.1.4";
          drv = buildMix {
            inherit version;
            name = "fine";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "fine";
              sha256 = "be3324cc454a42d80951cf6023b9954e9ff27c6daa255483b3e8d608670303f5";
            };
          };
        in
        drv;

      fsm =
        let
          version = "0.3.1";
          drv = buildMix {
            inherit version;
            name = "fsm";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "fsm";
              sha256 = "fbf0d53f89e9082b326b0b5828b94b4c549ff9d1452bbfd00b4d1ac082208e96";
            };
          };
        in
        drv;

      fss =
        let
          version = "0.1.1";
          drv = buildMix {
            inherit version;
            name = "fss";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "fss";
              sha256 = "78ad5955c7919c3764065b21144913df7515d52e228c09427a004afe9c1a16b0";
            };
          };
        in
        drv;

      fun_with_flags =
        let
          version = "1.12.0";
          drv = buildMix {
            inherit version;
            name = "fun_with_flags";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "fun_with_flags";
              sha256 = "9ed303bee60687f7a07dde2c036d3e8905771001ebd77790543ba5655a5f9066";
            };

            beamDeps = [
              phoenix_pubsub
              redix
            ];
          };
        in
        drv;

      gen_stage =
        let
          version = "1.3.2";
          drv = buildMix {
            inherit version;
            name = "gen_stage";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "gen_stage";
              sha256 = "0ffae547fa777b3ed889a6b9e1e64566217413d018cabd825f786e843ffe63e7";
            };
          };
        in
        drv;

      gproc =
        let
          version = "0.9.1";
          drv = buildRebar3 {
            inherit version;
            name = "gproc";

            src = fetchHex {
              inherit version;
              pkg = "gproc";
              sha256 = "905088e32e72127ed9466f0bac0d8e65704ca5e73ee5a62cb073c3117916d507";
            };
          };
        in
        drv;

      grpcbox =
        let
          version = "0.17.1";
          drv = buildRebar3 {
            inherit version;
            name = "grpcbox";

            src = fetchHex {
              inherit version;
              pkg = "grpcbox";
              sha256 = "4a3b5d7111daabc569dc9cbd9b202a3237d81c80bf97212fbc676832cb0ceb17";
            };

            beamDeps = [
              acceptor_pool
              chatterbox
              ctx
              gproc
            ];
          };
        in
        drv;

      heroicons = stdenv.mkDerivation {
        name = "heroicons";
        src = fetchFromGitHub {
          owner = "tailwindlabs";
          repo = "heroicons";
          rev = "88ab3a0d790e6a47404cba02800a6b25d2afae50";
          hash = "sha256-4yRqfY8r2Ar9Fr45ikD/8jK+H3g4veEHfXa9BorLxXg=";
        };
        buildPhase = ''
          mkdir $out
          ln -sv $src $out/src
        '';
      };

      hpack =
        let
          version = "0.3.0";
          drv = buildRebar3 {
            inherit version;
            name = "hpack";

            src = fetchHex {
              inherit version;
              pkg = "hpack_erl";
              sha256 = "d6137d7079169d8c485c6962dfe261af5b9ef60fbc557344511c1e65e3d95fb0";
            };
          };
        in
        drv;

      hpax =
        let
          version = "0.1.2";
          drv = buildMix {
            inherit version;
            name = "hpax";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "hpax";
              sha256 = "2c87843d5a23f5f16748ebe77969880e29809580efdaccd615cd3bed628a8c13";
            };
          };
        in
        drv;

      image =
        let
          version = "0.63.0";
          drv = buildMix {
            inherit version;
            name = "image";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "image";
              sha256 = "63b39a312f889bb61a04a4957977a7cd3fa23974ff56de3feebf46f69c5fa60e";
            };

            beamDeps = [
              jason
              phoenix_html
              plug
              rustler
              sweet_xml
              vix
            ];
          };
        in
        drv;

      jason =
        let
          version = "1.4.4";
          drv = buildMix {
            inherit version;
            name = "jason";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "jason";
              sha256 = "c5eb0cab91f094599f94d55bc63409236a8ec69a21a67814529e8d5f6cc90b3b";
            };

            beamDeps = [
              decimal
            ];
          };
        in
        drv;

      kafka_protocol =
        let
          version = "4.1.5";
          drv = buildRebar3 {
            inherit version;
            name = "kafka_protocol";

            src = fetchHex {
              inherit version;
              pkg = "kafka_protocol";
              sha256 = "c956c9357fef493b7072a35d0c3e2be02aa5186c804a412d29e62423bb15e5d9";
            };

            beamDeps = [
              crc32cer
            ];
          };
        in
        drv;

      lazy_html =
        let
          version = "0.1.10";
          drv = buildMix {
            inherit version;
            name = "lazy_html";
            appConfigPath = ./config;

            nativeBuildInputs = [
              lexbor
            ];

            src = fetchHex {
              inherit version;
              pkg = "lazy_html";
              sha256 = "50f67e5faa09d45a99c1ddf3fac004f051997877dc8974c5797bb5ccd8e27058";
            };

            beamDeps = [
              cc_precompiler
              elixir_make
              fine
            ];
          };
        in
        drv.override (workarounds.lazyHtml { } drv);

      mime =
        let
          version = "2.0.7";
          drv = buildMix {
            inherit version;
            name = "mime";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "mime";
              sha256 = "6171188e399ee16023ffc5b76ce445eb6d9672e2e241d2df6050f3c771e80ccd";
            };
          };
        in
        drv;

      nimble_options =
        let
          version = "1.1.1";
          drv = buildMix {
            inherit version;
            name = "nimble_options";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "nimble_options";
              sha256 = "821b2470ca9442c4b6984882fe9bb0389371b8ddec4d45a9504f00a66f650b44";
            };
          };
        in
        drv;

      nimble_parsec =
        let
          version = "1.4.2";
          drv = buildMix {
            inherit version;
            name = "nimble_parsec";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "nimble_parsec";
              sha256 = "4b21398942dda052b403bbe1da991ccd03a053668d147d53fb8c4e0efe09c973";
            };
          };
        in
        drv;

      opentelemetry =
        let
          version = "1.7.0";
          drv = buildRebar3 {
            inherit version;
            name = "opentelemetry";

            src = fetchHex {
              inherit version;
              pkg = "opentelemetry";
              sha256 = "a9173b058c4549bf824cbc2f1d2fa2adc5cdedc22aa3f0f826951187bbd53131";
            };

            beamDeps = [
              opentelemetry_api
            ];
          };
        in
        drv;

      opentelemetry_api =
        let
          version = "1.5.0";
          drv = buildMix {
            inherit version;
            name = "opentelemetry_api";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "opentelemetry_api";
              sha256 = "f53ec8a1337ae4a487d43ac89da4bd3a3c99ddf576655d071deed8b56a2d5dda";
            };
          };
        in
        drv;

      opentelemetry_exporter =
        let
          version = "1.10.0";
          drv = buildRebar3 {
            inherit version;
            name = "opentelemetry_exporter";

            src = fetchHex {
              inherit version;
              pkg = "opentelemetry_exporter";
              sha256 = "33a116ed7304cb91783f779dec02478f887c87988077bfd72840f760b8d4b952";
            };

            beamDeps = [
              grpcbox
              opentelemetry
              opentelemetry_api
              tls_certificate_check
            ];
          };
        in
        drv;

      phoenix =
        let
          version = "1.8.5";
          drv = buildMix {
            inherit version;
            name = "phoenix";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix";
              sha256 = "83b2bb125127e02e9f475c8e3e92736325b5b01b0b9b05407bcb4083b7a32485";
            };

            beamDeps = [
              bandit
              jason
              phoenix_pubsub
              phoenix_template
              plug
              plug_crypto
              telemetry
              websock_adapter
            ];
          };
        in
        drv;

      phoenix_html =
        let
          version = "4.3.0";
          drv = buildMix {
            inherit version;
            name = "phoenix_html";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_html";
              sha256 = "3eaa290a78bab0f075f791a46a981bbe769d94bc776869f4f3063a14f30497ad";
            };
          };
        in
        drv;

      phoenix_live_view =
        let
          version = "1.1.28";
          drv = buildMix {
            inherit version;
            name = "phoenix_live_view";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_live_view";
              sha256 = "24faad535b65089642c3a7d84088109dc58f49c1f1c5a978659855d643466353";
            };

            beamDeps = [
              jason
              lazy_html
              phoenix
              phoenix_html
              phoenix_template
              plug
              telemetry
            ];
          };
        in
        drv;

      phoenix_pubsub =
        let
          version = "2.2.0";
          drv = buildMix {
            inherit version;
            name = "phoenix_pubsub";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_pubsub";
              sha256 = "adc313a5bf7136039f63cfd9668fde73bba0765e0614cba80c06ac9460ff3e96";
            };
          };
        in
        drv;

      phoenix_template =
        let
          version = "1.0.4";
          drv = buildMix {
            inherit version;
            name = "phoenix_template";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_template";
              sha256 = "2c0c81f0e5c6753faf5cca2f229c9709919aba34fab866d3bc05060c9c444206";
            };

            beamDeps = [
              phoenix_html
            ];
          };
        in
        drv;

      plug =
        let
          version = "1.19.1";
          drv = buildMix {
            inherit version;
            name = "plug";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "plug";
              sha256 = "560a0017a8f6d5d30146916862aaf9300b7280063651dd7e532b8be168511e62";
            };

            beamDeps = [
              mime
              plug_crypto
              telemetry
            ];
          };
        in
        drv;

      plug_crypto =
        let
          version = "2.1.1";
          drv = buildMix {
            inherit version;
            name = "plug_crypto";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "plug_crypto";
              sha256 = "6470bce6ffe41c8bd497612ffde1a7e4af67f36a15eea5f921af71cf3e11247c";
            };
          };
        in
        drv;

      png =
        let
          version = "0.2.1";
          drv = buildRebar3 {
            inherit version;
            name = "png";

            src = fetchHex {
              inherit version;
              pkg = "png";
              sha256 = "279345e07108c604871a21f1c91f716810ab559af2b20d6f302e0a98265ef72e";
            };
          };
        in
        drv;

      postgrex =
        let
          version = "0.22.0";
          drv = buildMix {
            inherit version;
            name = "postgrex";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "postgrex";
              sha256 = "a68c4261e299597909e03e6f8ff5a13876f5caadaddd0d23af0d0a61afcc5d84";
            };

            beamDeps = [
              db_connection
              decimal
              jason
              table
            ];
          };
        in
        drv;

      redix =
        let
          version = "1.5.3";
          drv = buildMix {
            inherit version;
            name = "redix";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "redix";
              sha256 = "7b06fb5246373af41f5826b03334dfa3f636347d4d5d98b4d455b699d425ae7e";
            };

            beamDeps = [
              castore
              nimble_options
              telemetry
            ];
          };
        in
        drv;

      rustler =
        let
          version = "0.36.2";
          drv = buildMix {
            inherit version;
            name = "rustler";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "rustler";
              sha256 = "93832a6dbc1166739a19cd0c25e110e4cf891f16795deb9361dfcae95f6c88fe";
            };

            beamDeps = [
              jason
              toml
            ];
          };
        in
        drv;

      rustler_precompiled =
        let
          version = "0.9.0";
          drv = buildMix {
            inherit version;
            name = "rustler_precompiled";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "rustler_precompiled";
              sha256 = "471d97315bd3bf7b64623418b3693eedd8e47de3d1cb79a0ac8f9da7d770d94c";
            };

            beamDeps = [
              rustler
            ];
          };
        in
        drv;

      snappyer =
        let
          version = "1.2.9";
          drv = buildRebar3 {
            inherit version;
            name = "snappyer";

            src = fetchHex {
              inherit version;
              pkg = "snappyer";
              sha256 = "18d00ca218ae613416e6eecafe1078db86342a66f86277bd45c95f05bf1c8b29";
            };
          };
        in
        drv;

      ssl_verify_fun =
        let
          version = "1.1.7";
          drv = buildMix {
            inherit version;
            name = "ssl_verify_fun";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ssl_verify_fun";
              sha256 = "fe4c190e8f37401d30167c8c405eda19469f34577987c76dde613e838bbc67f8";
            };
          };
        in
        drv;

      sweet_xml =
        let
          version = "0.7.5";
          drv = buildMix {
            inherit version;
            name = "sweet_xml";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "sweet_xml";
              sha256 = "193b28a9b12891cae351d81a0cead165ffe67df1b73fe5866d10629f4faefb12";
            };
          };
        in
        drv;

      table =
        let
          version = "0.1.2";
          drv = buildMix {
            inherit version;
            name = "table";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "table";
              sha256 = "7e99bc7efef806315c7e65640724bf165c3061cdc5d854060f74468367065029";
            };
          };
        in
        drv;

      table_rex =
        let
          version = "4.1.0";
          drv = buildMix {
            inherit version;
            name = "table_rex";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "table_rex";
              sha256 = "95932701df195d43bc2d1c6531178fc8338aa8f38c80f098504d529c43bc2601";
            };
          };
        in
        drv;

      telemetry =
        let
          version = "1.4.1";
          drv = buildRebar3 {
            inherit version;
            name = "telemetry";

            src = fetchHex {
              inherit version;
              pkg = "telemetry";
              sha256 = "2172e05a27531d3d31dd9782841065c50dd5c3c7699d95266b2edd54c2dafa1c";
            };
          };
        in
        drv;

      thousand_island =
        let
          version = "1.4.3";
          drv = buildMix {
            inherit version;
            name = "thousand_island";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "thousand_island";
              sha256 = "6e4ce09b0fd761a58594d02814d40f77daff460c48a7354a15ab353bb998ea0b";
            };

            beamDeps = [
              telemetry
            ];
          };
        in
        drv;

      tls_certificate_check =
        let
          version = "1.32.0";
          drv = buildRebar3 {
            inherit version;
            name = "tls_certificate_check";

            src = fetchHex {
              inherit version;
              pkg = "tls_certificate_check";
              sha256 = "38e38db768244d808e11ed27f812e7d927ea5f999007b07d0473db44d7f7cc51";
            };

            beamDeps = [
              ssl_verify_fun
            ];
          };
        in
        drv;

      tokenizers =
        let
          version = "0.3.2";
          drv = buildMix {
            inherit version;
            name = "tokenizers";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "tokenizers";
              sha256 = "f6dd9a798e81cf2f3359e1731836ed0a351cae4da5d5d570a7ef3d0543e9cf85";
            };

            beamDeps = [
              castore
              rustler
              rustler_precompiled
            ];
          };
        in
        drv.override (
          workarounds.rustlerPrecompiled {
            buildInputs = [ oniguruma ];
            nativeBuildInputs = [ pkg-config ];
            env.RUSTONIG_SYSTEM_LIBONIG = "1";
          } drv
        );

      toml =
        let
          version = "0.7.0";
          drv = buildMix {
            inherit version;
            name = "toml";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "toml";
              sha256 = "0690246a2478c1defd100b0c9b89b4ea280a22be9a7b313a8a058a2408a2fa70";
            };
          };
        in
        drv;

      trie =
        let
          version = "2.0.7";
          drv = buildRebar3 {
            inherit version;
            name = "trie";

            src = fetchHex {
              inherit version;
              pkg = "trie";
              sha256 = "6b86092654bc6383d5c72dfbb32b466d3a70d3e95be37538bb5500ee888fa944";
            };
          };
        in
        drv;

      unicode =
        let
          version = "1.21.1";
          drv = buildMix {
            inherit version;
            name = "unicode";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "unicode";
              sha256 = "aa8eb52bb0a25b8c3c08bdc3d4b1d0f53e2eb678800a80434bff0314c7bd834b";
            };

            patches = [
              (writeText "unicode-accessible-data-dir.patch" ''
                diff --git a/lib/unicode.ex b/lib/unicode.ex
                index 8224c3c..3c0bb3a 100644
                --- a/lib/unicode.ex
                +++ b/lib/unicode.ex
                @@ -46,7 +46,7 @@ defmodule Unicode do
                     :hebrew | :buginese | :tifinagh

                   @doc false
                -  @data_dir Path.join(__DIR__, "../data") |> Path.expand()
                +  @data_dir "/tmp/unicode-data"
                   def data_dir do
                     @data_dir
                   end
              '')
            ];

            postUnpack = ''
              test -e /tmp/unicode-data ||
                ln -sfv ${unicode.src}/data /tmp/unicode-data
            '';
          };
        in
        drv;

      unicode_set =
        let
          version = "1.6.1";
          drv = buildMix {
            inherit version;
            name = "unicode_set";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "unicode_set";
              sha256 = "9e31ce44bacc294348a7e0bee0cf949b5226b32846112e324732004c59d7d7a0";
            };

            beamDeps = [
              nimble_parsec
              unicode
            ];
          };
        in
        drv;

      unicode_string =
        let
          version = "1.8.0";
          drv = buildMix {
            inherit version;
            name = "unicode_string";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "unicode_string";
              sha256 = "f7fe735b263fbcbfb6f9cf6d09bd3cdb8da9b21fa8bd38a3aee015e8506d3a21";
            };

            beamDeps = [
              ex_cldr
              jason
              sweet_xml
              trie
              unicode_set
            ];

            postUnpack = ''
              test -e /tmp/unicode-data ||
                ln -sfv ${unicode.src}/data /tmp/unicode-data
            '';
          };
        in
        drv;

      vix =
        let
          version = "0.38.0";
          drv = buildMix {
            inherit version;
            name = "vix";
            appConfigPath = ./config;

            env.VIX_COMPILATION_MODE = "PLATFORM_PROVIDED_LIBVIPS";

            nativeBuildInputs = [
              pkg-config
              vips
            ];

            src = fetchHex {
              inherit version;
              pkg = "vix";
              sha256 = "dca58f654922fa678d5df8e028317483d9c0f8acb2e2714076a8468695687aa7";
            };

            beamDeps = [
              cc_precompiler
              elixir_make
            ];
          };
        in
        drv.override (workarounds.elixirMake { } drv);

      websock =
        let
          version = "0.5.3";
          drv = buildMix {
            inherit version;
            name = "websock";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "websock";
              sha256 = "6105453d7fac22c712ad66fab1d45abdf049868f253cf719b625151460b8b453";
            };
          };
        in
        drv;

      websock_adapter =
        let
          version = "0.5.9";
          drv = buildMix {
            inherit version;
            name = "websock_adapter";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "websock_adapter";
              sha256 = "5534d5c9adad3c18a0f58a9371220d75a803bf0b9a3d87e6fe072faaeed76a08";
            };

            beamDeps = [
              bandit
              plug
              websock
            ];
          };
        in
        drv;

    };
in
self
