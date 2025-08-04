{
  pkgs,
  lib,
  beamPackages,
  overrides ? (x: y: { }),
  overrideFenixOverlay ? null,
}:

let
  buildMix = lib.makeOverridable beamPackages.buildMix;
  buildRebar3 = lib.makeOverridable beamPackages.buildRebar3;

  workarounds = {
    portCompiler = _unusedArgs: old: {
      buildPlugins = [ pkgs.beamPackages.pc ];
    };

    rustlerPrecompiled =
      {
        toolchain ? null,
        ...
      }:
      old:
      let
        extendedPkgs = pkgs.extend fenixOverlay;
        fenixOverlay =
          if overrideFenixOverlay == null then
            import "${
              fetchTarball {
                url = "https://github.com/nix-community/fenix/archive/056c9393c821a4df356df6ce7f14c722dc8717ec.tar.gz";
                sha256 = "sha256:1cdfh6nj81gjmn689snigidyq7w98gd8hkl5rvhly6xj7vyppmnd";
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
          (extendedPkgs.makeRustPlatform {
            inherit (fenix) cargo rustc;
          }).buildRustPackage
            {
              pname = "${old.packageName}-native";
              version = old.version;
              src = nativeDir;
              cargoLock = {
                lockFile = "${nativeDir}/Cargo.lock";
              };
              nativeBuildInputs = [
                extendedPkgs.cmake
              ];
              doCheck = false;
            };

      in
      {
        nativeBuildInputs = [ extendedPkgs.cargo ];

        env.RUSTLER_PRECOMPILED_FORCE_BUILD_ALL = "true";
        env.RUSTLER_PRECOMPILED_GLOBAL_CACHE_PATH = "unused-but-required";

        preConfigure = ''
          mkdir -p priv/native
          for lib in ${native}/lib/*
          do
            ln -s "$lib" "priv/native/$(basename "$lib")"
          done
        '';

        buildPhase = ''
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
              | sed 's/defmodule \(.*\) do/config :${old.packageName}, \1, skip_compilation?: true/'
            echo "***********************************************"
            exit 1
          }
          trap suggestion ERR
          ${old.buildPhase}
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
              name = "nightly-2024-11-01";
              sha256 = "sha256-wq7bZ1/IlmmLkSa3GUJgK17dTWcKyf5A+ndS9yRwB88=";
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
          version = "1.0.0";
          drv = buildRebar3 {
            inherit version;
            name = "acceptor_pool";

            src = fetchHex {
              inherit version;
              pkg = "acceptor_pool";
              sha256 = "0cbcd83fdc8b9ad2eee2067ef8b91a14858a5883cb7cd800e6fcd5803e158788";
            };
          };
        in
        drv;

      aws_signature =
        let
          version = "0.3.3";
          drv = buildRebar3 {
            inherit version;
            name = "aws_signature";

            src = fetchHex {
              inherit version;
              pkg = "aws_signature";
              sha256 = "87e8f42b8e49002aa8d0350a71d13d69ea91b9afb4ca9b526ae36db1d585c924";
            };
          };
        in
        drv;

      bandit =
        let
          version = "4f15f029e7aa17f8e7f98d55b0e94c684dee0971";
          drv = buildMix {
            inherit version;
            name = "bandit";
            appConfigPath = ./config;

            src = pkgs.fetchFromGitHub {
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
          version = "1.0.11";
          drv = buildMix {
            inherit version;
            name = "castore";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "castore";
              sha256 = "e03990b4db988df56262852f20de0f659871c35154691427a5047f4967a16a62";
            };
          };
        in
        drv;

      cc_precompiler =
        let
          version = "0.1.10";
          drv = buildMix {
            inherit version;
            name = "cc_precompiler";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "cc_precompiler";
              sha256 = "f6e046254e53cd6b41c6bacd70ae728011aa82b2742a80d6e2214855c6e06b22";
            };

            beamDeps = [
              elixir_make
            ];
          };
        in
        drv;

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
          version = "2.28.2";
          drv = buildMix {
            inherit version;
            name = "cldr_utils";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "cldr_utils";
              sha256 = "c506eb1a170ba7cdca59b304ba02a56795ed119856662f6b1a420af80ec42551";
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
          version = "2.7.0";
          drv = buildMix {
            inherit version;
            name = "db_connection";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "db_connection";
              sha256 = "dcf08f31b2701f857dfc787fbad78223d61a32204f217f15e881dd93e4bdd3ff";
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
          version = "1.4.7";
          drv = buildMix {
            inherit version;
            name = "eventstore";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "eventstore";
              sha256 = "9eedd728437848cbfeda3968b8d3092f15a66325f15fcd77941047e9ff39f916";
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
          version = "2.40.2";
          drv = buildMix {
            inherit version;
            name = "ex_cldr";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr";
              sha256 = "cd9039ca9a7c61b99c053a16bd2201ebd7d1c87b49499a4c6d761ec14bca4442";
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
          version = "1.26.4";
          drv = buildMix {
            inherit version;
            name = "ex_cldr_calendars";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr_calendars";
              sha256 = "6538ee5328ddf5457b5f11bfccb465405d0d7011ac0bb24d826af0be00335170";
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
          version = "2.16.3";
          drv = buildMix {
            inherit version;
            name = "ex_cldr_currencies";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr_currencies";
              sha256 = "4d1b5f8449fdf0ece6a2e5c7401ad8fcfde77ee6ea480bddc16e266dfa2b570c";
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
          version = "2.20.3";
          drv = buildMix {
            inherit version;
            name = "ex_cldr_dates_times";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr_dates_times";
              sha256 = "52fe1493f44d2420d4af80dbafb65c89bfd17f0758a98c4ad61182518bb6e5a1";
            };

            beamDeps = [
              ex_cldr
              ex_cldr_calendars
              jason
            ];
          };
        in
        drv;

      ex_cldr_numbers =
        let
          version = "2.33.4";
          drv = buildMix {
            inherit version;
            name = "ex_cldr_numbers";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_cldr_numbers";
              sha256 = "d15b7e217e9e60c328e73045e51dc67d7ac5d2997247b833efab2c69b2ed06f5";
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

      ex_keccak =
        let
          version = "0.7.6";
          drv = buildMix {
            inherit version;
            name = "ex_keccak";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_keccak";
              sha256 = "9d1568424eb7b995e480d1b7f0c1e914226ee625496600abb922bba6f5cdc5e4";
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
          version = "0.7.3";
          drv = buildMix {
            inherit version;
            name = "ex_secp256k1";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "ex_secp256k1";
              sha256 = "ea63159442f4d8143166cd1507da03edc43216d6e7c6bac4b416bdce04f0daa8";
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
          version = "0.10.1";
          drv = buildMix {
            inherit version;
            name = "explorer";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "explorer";
              sha256 = "4e3efc45d4981a568405a181ebf206ba208622a5e94048c9d713b27a053c3197";
            };

            beamDeps = [
              aws_signature
              castore
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

      finch =
        let
          version = "0.19.0";
          drv = buildMix {
            inherit version;
            name = "finch";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "finch";
              sha256 = "fc5324ce209125d1e2fa0fcd2634601c52a787aff1cd33ee833664a5af4ea2b6";
            };

            beamDeps = [
              mime
              mint
              nimble_options
              nimble_pool
              telemetry
            ];
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
              redix
            ];
          };
        in
        drv;

      gen_stage =
        let
          version = "1.2.1";
          drv = buildMix {
            inherit version;
            name = "gen_stage";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "gen_stage";
              sha256 = "83e8be657fa05b992ffa6ac1e3af6d57aa50aace8f691fcf696ff02f8335b001";
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

      heroicons = pkgs.fetchFromGitHub {
        owner = "tailwindlabs";
        repo = "heroicons";
        rev = "88ab3a0d790e6a47404cba02800a6b25d2afae50";
        hash = "sha256-4yRqfY8r2Ar9Fr45ikD/8jK+H3g4veEHfXa9BorLxXg=";
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
          version = "0.58.0";
          drv = buildMix {
            inherit version;
            name = "image";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "image";
              sha256 = "b5d472360caa7e8a113aeaa06559c705b593361c9d1391e1992b66ed2d7b6889";
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

      mime =
        let
          version = "2.0.6";
          drv = buildMix {
            inherit version;
            name = "mime";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "mime";
              sha256 = "c9945363a6b26d747389aac3643f8e0e09d30499a138ad64fe8fd1d13d9b153e";
            };
          };
        in
        drv;

      mint =
        let
          version = "1.6.2";
          drv = buildMix {
            inherit version;
            name = "mint";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "mint";
              sha256 = "5ee441dffc1892f1ae59127f74afe8fd82fda6587794278d924e4d90ea3d63f9";
            };

            beamDeps = [
              castore
              hpax
            ];
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

      nimble_pool =
        let
          version = "1.1.0";
          drv = buildMix {
            inherit version;
            name = "nimble_pool";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "nimble_pool";
              sha256 = "af2e4e6b34197db81f7aad230c1118eac993acc0dae6bc83bac0126d4ae0813a";
            };
          };
        in
        drv;

      opentelemetry =
        let
          version = "1.5.0";
          drv = buildRebar3 {
            inherit version;
            name = "opentelemetry";

            src = fetchHex {
              inherit version;
              pkg = "opentelemetry";
              sha256 = "cdf4f51d17b592fc592b9a75f86a6f808c23044ba7cf7b9534debbcc5c23b0ee";
            };

            beamDeps = [
              opentelemetry_api
            ];
          };
        in
        drv;

      opentelemetry_api =
        let
          version = "1.4.0";
          drv = buildMix {
            inherit version;
            name = "opentelemetry_api";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "opentelemetry_api";
              sha256 = "3dfbbfaa2c2ed3121c5c483162836c4f9027def469c41578af5ef32589fcfc58";
            };
          };
        in
        drv;

      opentelemetry_exporter =
        let
          version = "1.8.0";
          drv = buildRebar3 {
            inherit version;
            name = "opentelemetry_exporter";

            src = fetchHex {
              inherit version;
              pkg = "opentelemetry_exporter";
              sha256 = "a1f9f271f8d3b02b81462a6bfef7075fd8457fdb06adff5d2537df5e2264d9af";
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

      phoenix_html =
        let
          version = "4.2.1";
          drv = buildMix {
            inherit version;
            name = "phoenix_html";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "phoenix_html";
              sha256 = "cff108100ae2715dd959ae8f2a8cef8e20b593f8dfd031c9cba92702cf23e053";
            };
          };
        in
        drv;

      plug =
        let
          version = "1.16.1";
          drv = buildMix {
            inherit version;
            name = "plug";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "plug";
              sha256 = "a13ff6b9006b03d7e33874945b2755253841b238c34071ed85b0e86057f8cddc";
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
          version = "2.1.0";
          drv = buildMix {
            inherit version;
            name = "plug_crypto";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "plug_crypto";
              sha256 = "131216a4b030b8f8ce0f26038bc4421ae60e4bb95c5cf5395e1421437824c4fa";
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
          version = "0.19.3";
          drv = buildMix {
            inherit version;
            name = "postgrex";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "postgrex";
              sha256 = "d31c28053655b78f47f948c85bb1cf86a9c1f8ead346ba1aa0d0df017fa05b61";
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
          version = "1.5.2";
          drv = buildMix {
            inherit version;
            name = "redix";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "redix";
              sha256 = "78538d184231a5d6912f20567d76a49d1be7d3fca0e1aaaa20f4df8e1142dcb8";
            };

            beamDeps = [
              castore
              nimble_options
              telemetry
            ];
          };
        in
        drv;

      req =
        let
          version = "0.5.8";
          drv = buildMix {
            inherit version;
            name = "req";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "req";
              sha256 = "d7fc5898a566477e174f26887821a3c5082b243885520ee4b45555f5d53f40ef";
            };

            beamDeps = [
              finch
              jason
              mime
              plug
            ];
          };
        in
        drv;

      rustler =
        let
          version = "0.34.0";
          drv = buildMix {
            inherit version;
            name = "rustler";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "rustler";
              sha256 = "1d0c7449482b459513003230c0e2422b0252245776fe6fd6e41cb2b11bd8e628";
            };

            beamDeps = [
              jason
              req
              toml
            ];
          };
        in
        drv;

      rustler_precompiled =
        let
          version = "0.8.2";
          drv = buildMix {
            inherit version;
            name = "rustler_precompiled";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "rustler_precompiled";
              sha256 = "63d1bd5f8e23096d1ff851839923162096364bac8656a4a3c00d1fff8e83ee0a";
            };

            beamDeps = [
              castore
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
          version = "4.0.0";
          drv = buildMix {
            inherit version;
            name = "table_rex";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "table_rex";
              sha256 = "c35c4d5612ca49ebb0344ea10387da4d2afe278387d4019e4d8111e815df8f55";
            };
          };
        in
        drv;

      telemetry =
        let
          version = "1.3.0";
          drv = buildRebar3 {
            inherit version;
            name = "telemetry";

            src = fetchHex {
              inherit version;
              pkg = "telemetry";
              sha256 = "7015fc8919dbe63764f4b4b87a95b7c0996bd539e0d499be6ec9d7f3875b79e6";
            };
          };
        in
        drv;

      thousand_island =
        let
          version = "1.3.9";
          drv = buildMix {
            inherit version;
            name = "thousand_island";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "thousand_island";
              sha256 = "25ab4c07badadf7f87adb4ab414e0ed374e5f19e72503aa85132caa25776e54f";
            };

            beamDeps = [
              telemetry
            ];
          };
        in
        drv;

      tls_certificate_check =
        let
          version = "1.25.0";
          drv = buildRebar3 {
            inherit version;
            name = "tls_certificate_check";

            src = fetchHex {
              inherit version;
              pkg = "tls_certificate_check";
              sha256 = "167343ccf50538cf2faf61a3f1460e749b3edf2ecef55516af2b5834362abcb1";
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
        drv.override (workarounds.rustlerPrecompiled { } drv);

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
          version = "1.20.0";
          drv = buildMix {
            inherit version;
            name = "unicode";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "unicode";
              sha256 = "fa581cf80b3b1b7f42e4d24a69109dfac465cec27a62c661306c81f4ab35894c";
            };

            patches = [
              (pkgs.writeText "unicode-accessible-data-dir.patch" ''
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
          version = "1.5.0";
          drv = buildMix {
            inherit version;
            name = "unicode_set";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "unicode_set";
              sha256 = "6c7f200e52fb90434d6b783eaa4e0ea303cfc4844ea25b2fc1ba3eb8a6901b11";
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
          version = "1.7.0";
          drv = buildMix {
            inherit version;
            name = "unicode_string";
            appConfigPath = ./config;

            src = fetchHex {
              inherit version;
              pkg = "unicode_string";
              sha256 = "490f0550a1c9c70b869284975f81e09a7f9de0381e1b2d43e0779e60934b41f2";
            };

            beamDeps = [
              ex_cldr
              jason
              sweet_xml
              trie
              unicode
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
          version = "0.33.0";
          drv = buildMix {
            inherit version;
            name = "vix";
            appConfigPath = ./config;

            VIX_COMPILATION_MODE = "PLATFORM_PROVIDED_LIBVIPS";

            nativeBuildInputs = with pkgs; [
              pkg-config
              vips
            ];

            src = fetchHex {
              inherit version;
              pkg = "vix";
              sha256 = "9acde72b27bdfeadeb51f790f7a6cc0d06cf555718c05cf57e43c5cf93d8471b";
            };

            beamDeps = [
              castore
              cc_precompiler
              elixir_make
            ];
          };
        in
        drv;

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

    };
in
self
