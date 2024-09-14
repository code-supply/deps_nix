{ pkgs, lib, beamPackages, overrides ? (x: y: { }) }:

let
  buildMix = lib.makeOverridable beamPackages.buildMix;
  buildRebar3 = lib.makeOverridable beamPackages.buildRebar3;

  defaultOverrides = (final: prev:

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
              nativeBuildInputs = [ extendedPkgs.cmake ];
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
    builtins.mapAttrs applyOverrides prev);

  self = packages // (defaultOverrides self packages) // (overrides self packages);

  packages = with beamPackages; with self; {
    acceptor_pool =
      let
        version = "1.0.0";
      in
      buildRebar3 {
        inherit version;
        name = "acceptor_pool";

        src = fetchHex {
          inherit version;
          pkg = "acceptor_pool";
          sha256 = "0cbcd83fdc8b9ad2eee2067ef8b91a14858a5883cb7cd800e6fcd5803e158788";
        };
      };

    aws_signature =
      let
        version = "0.3.2";
      in
      buildRebar3 {
        inherit version;
        name = "aws_signature";

        src = fetchHex {
          inherit version;
          pkg = "aws_signature";
          sha256 = "b0daf61feb4250a8ab0adea60db3e336af732ff71dd3fb22e45ae3dcbd071e44";
        };
      };

    bandit =
      let
        version = "4f15f029e7aa17f8e7f98d55b0e94c684dee0971";
      in
      buildMix {
        inherit version;
        name = "bandit";

        src = builtins.fetchGit {
          url = "https://github.com/mtrudel/bandit.git";
          rev = "4f15f029e7aa17f8e7f98d55b0e94c684dee0971";
          allRefs = true;
        };

        beamDeps = [ thousand_island plug websock hpax telemetry ];
      };

    castore =
      let
        version = "1.0.8";
      in
      buildMix {
        inherit version;
        name = "castore";

        src = fetchHex {
          inherit version;
          pkg = "castore";
          sha256 = "0b2b66d2ee742cb1d9cb8c8be3b43c3a70ee8651f37b75a8b982e036752983f1";
        };
      };

    chatterbox =
      let
        version = "0.15.1";
      in
      buildRebar3 {
        inherit version;
        name = "chatterbox";

        src = fetchHex {
          inherit version;
          pkg = "ts_chatterbox";
          sha256 = "4f75b91451338bc0da5f52f3480fa6ef6e3a2aeecfc33686d6b3d0a0948f31aa";
        };

        beamDeps = [ hpack ];
      };

    cldr_utils =
      let
        version = "2.25.0";
      in
      buildMix {
        inherit version;
        name = "cldr_utils";

        src = fetchHex {
          inherit version;
          pkg = "cldr_utils";
          sha256 = "9041660356ffa1129e0d87d110e188f5da0e0bba94fb915e11275e04ace066e1";
        };

        beamDeps = [ castore decimal ];
      };

    ctx =
      let
        version = "0.6.0";
      in
      buildRebar3 {
        inherit version;
        name = "ctx";

        src = fetchHex {
          inherit version;
          pkg = "ctx";
          sha256 = "a14ed2d1b67723dbebbe423b28d7615eb0bdcba6ff28f2d1f1b0a7e1d4aa5fc2";
        };
      };

    db_connection =
      let
        version = "2.6.0";
      in
      buildMix {
        inherit version;
        name = "db_connection";

        src = fetchHex {
          inherit version;
          pkg = "db_connection";
          sha256 = "c2f992d15725e721ec7fbc1189d4ecdb8afef76648c746a8e1cad35e3b8a35f3";
        };

        beamDeps = [ telemetry ];
      };

    decimal =
      let
        version = "2.1.1";
      in
      buildMix {
        inherit version;
        name = "decimal";

        src = fetchHex {
          inherit version;
          pkg = "decimal";
          sha256 = "53cfe5f497ed0e7771ae1a475575603d77425099ba5faef9394932b35020ffcc";
        };
      };

    digital_token =
      let
        version = "0.6.0";
      in
      buildMix {
        inherit version;
        name = "digital_token";

        src = fetchHex {
          inherit version;
          pkg = "digital_token";
          sha256 = "2455d626e7c61a128b02a4a8caddb092548c3eb613ac6f6a85e4cbb6caddc4d1";
        };

        beamDeps = [ cldr_utils jason ];
      };

    eventstore =
      let
        version = "1.4.4";
      in
      buildMix {
        inherit version;
        name = "eventstore";

        src = fetchHex {
          inherit version;
          pkg = "eventstore";
          sha256 = "1cb0b76199dccff9625c2317b4500f51016c7ef6010c0de60e5f89bc6f8cb811";
        };

        beamDeps = [ fsm gen_stage jason postgrex ];
      };

    ex_cldr =
      let
        version = "2.38.1";
      in
      buildMix {
        inherit version;
        name = "ex_cldr";

        src = fetchHex {
          inherit version;
          pkg = "ex_cldr";
          sha256 = "1e083be8d5f7e5d2cc993967c5d99864bacd3456b5f74d4a50985e102ad9c449";
        };

        beamDeps = [ cldr_utils decimal jason ];
      };

    ex_cldr_calendars =
      let
        version = "1.23.1";
      in
      buildMix {
        inherit version;
        name = "ex_cldr_calendars";

        src = fetchHex {
          inherit version;
          pkg = "ex_cldr_calendars";
          sha256 = "2983f002016c283d14ee838d1950d2f9a1e58e8b19a2145d95079874fe6de10d";
        };

        beamDeps = [ ex_cldr_numbers jason ];
      };

    ex_cldr_currencies =
      let
        version = "2.16.1";
      in
      buildMix {
        inherit version;
        name = "ex_cldr_currencies";

        src = fetchHex {
          inherit version;
          pkg = "ex_cldr_currencies";
          sha256 = "095d5e973bf0ee066dd1153990d10cb6fa6d8ff0e028295bdce7a7821c70a0e4";
        };

        beamDeps = [ ex_cldr jason ];
      };

    ex_cldr_dates_times =
      let
        version = "2.17.1";
      in
      buildMix {
        inherit version;
        name = "ex_cldr_dates_times";

        src = fetchHex {
          inherit version;
          pkg = "ex_cldr_dates_times";
          sha256 = "6819cd84aaa0a2142ee660cbfb8aae2af95b8acb30492b0607ad723904b07e1e";
        };

        beamDeps = [ ex_cldr_calendars ex_cldr_numbers jason ];
      };

    ex_cldr_numbers =
      let
        version = "2.33.1";
      in
      buildMix {
        inherit version;
        name = "ex_cldr_numbers";

        src = fetchHex {
          inherit version;
          pkg = "ex_cldr_numbers";
          sha256 = "c003bfaa3fdee6bab5195f128b94038c2ce1cf4879a759eef431dd075d9a5dac";
        };

        beamDeps = [ decimal digital_token ex_cldr ex_cldr_currencies jason ];
      };

    explorer =
      let
        version = "0.9.2";
      in
      buildMix {
        inherit version;
        name = "explorer";

        src = fetchHex {
          inherit version;
          pkg = "explorer";
          sha256 = "63057e318d613c1819bd8bee2d8ed4f7061c3136edc6832ad18243d28e6344eb";
        };

        beamDeps = [ aws_signature castore fss rustler rustler_precompiled table table_rex ];
      };

    finch =
      let
        version = "0.18.0";
      in
      buildMix {
        inherit version;
        name = "finch";

        src = fetchHex {
          inherit version;
          pkg = "finch";
          sha256 = "69f5045b042e531e53edc2574f15e25e735b522c37e2ddb766e15b979e03aa65";
        };

        beamDeps = [ castore mime mint nimble_options nimble_pool telemetry ];
      };

    fsm =
      let
        version = "0.3.1";
      in
      buildMix {
        inherit version;
        name = "fsm";

        src = fetchHex {
          inherit version;
          pkg = "fsm";
          sha256 = "fbf0d53f89e9082b326b0b5828b94b4c549ff9d1452bbfd00b4d1ac082208e96";
        };
      };

    fss =
      let
        version = "0.1.1";
      in
      buildMix {
        inherit version;
        name = "fss";

        src = fetchHex {
          inherit version;
          pkg = "fss";
          sha256 = "78ad5955c7919c3764065b21144913df7515d52e228c09427a004afe9c1a16b0";
        };
      };

    gen_stage =
      let
        version = "1.2.1";
      in
      buildMix {
        inherit version;
        name = "gen_stage";

        src = fetchHex {
          inherit version;
          pkg = "gen_stage";
          sha256 = "83e8be657fa05b992ffa6ac1e3af6d57aa50aace8f691fcf696ff02f8335b001";
        };
      };

    gproc =
      let
        version = "0.9.1";
      in
      buildRebar3 {
        inherit version;
        name = "gproc";

        src = fetchHex {
          inherit version;
          pkg = "gproc";
          sha256 = "905088e32e72127ed9466f0bac0d8e65704ca5e73ee5a62cb073c3117916d507";
        };
      };

    grpcbox =
      let
        version = "0.17.1";
      in
      buildRebar3 {
        inherit version;
        name = "grpcbox";

        src = fetchHex {
          inherit version;
          pkg = "grpcbox";
          sha256 = "4a3b5d7111daabc569dc9cbd9b202a3237d81c80bf97212fbc676832cb0ceb17";
        };

        beamDeps = [ acceptor_pool chatterbox ctx gproc ];
      };

    hpack =
      let
        version = "0.3.0";
      in
      buildRebar3 {
        inherit version;
        name = "hpack";

        src = fetchHex {
          inherit version;
          pkg = "hpack_erl";
          sha256 = "d6137d7079169d8c485c6962dfe261af5b9ef60fbc557344511c1e65e3d95fb0";
        };
      };

    hpax =
      let
        version = "0.1.2";
      in
      buildMix {
        inherit version;
        name = "hpax";

        src = fetchHex {
          inherit version;
          pkg = "hpax";
          sha256 = "2c87843d5a23f5f16748ebe77969880e29809580efdaccd615cd3bed628a8c13";
        };
      };

    jason =
      let
        version = "1.4.1";
      in
      buildMix {
        inherit version;
        name = "jason";

        src = fetchHex {
          inherit version;
          pkg = "jason";
          sha256 = "fbb01ecdfd565b56261302f7e1fcc27c4fb8f32d56eab74db621fc154604a7a1";
        };

        beamDeps = [ decimal ];
      };

    mime =
      let
        version = "2.0.5";
      in
      buildMix {
        inherit version;
        name = "mime";

        src = fetchHex {
          inherit version;
          pkg = "mime";
          sha256 = "da0d64a365c45bc9935cc5c8a7fc5e49a0e0f9932a761c55d6c52b142780a05c";
        };
      };

    mint =
      let
        version = "1.6.2";
      in
      buildMix {
        inherit version;
        name = "mint";

        src = fetchHex {
          inherit version;
          pkg = "mint";
          sha256 = "5ee441dffc1892f1ae59127f74afe8fd82fda6587794278d924e4d90ea3d63f9";
        };

        beamDeps = [ castore hpax ];
      };

    nimble_options =
      let
        version = "1.1.1";
      in
      buildMix {
        inherit version;
        name = "nimble_options";

        src = fetchHex {
          inherit version;
          pkg = "nimble_options";
          sha256 = "821b2470ca9442c4b6984882fe9bb0389371b8ddec4d45a9504f00a66f650b44";
        };
      };

    nimble_pool =
      let
        version = "1.1.0";
      in
      buildMix {
        inherit version;
        name = "nimble_pool";

        src = fetchHex {
          inherit version;
          pkg = "nimble_pool";
          sha256 = "af2e4e6b34197db81f7aad230c1118eac993acc0dae6bc83bac0126d4ae0813a";
        };
      };

    opentelemetry =
      let
        version = "1.4.0";
      in
      buildRebar3 {
        inherit version;
        name = "opentelemetry";

        src = fetchHex {
          inherit version;
          pkg = "opentelemetry";
          sha256 = "50b32ce127413e5d87b092b4d210a3449ea80cd8224090fe68d73d576a3faa15";
        };

        beamDeps = [ opentelemetry_api opentelemetry_semantic_conventions ];
      };

    opentelemetry_api =
      let
        version = "1.3.0";
      in
      buildMix {
        inherit version;
        name = "opentelemetry_api";

        src = fetchHex {
          inherit version;
          pkg = "opentelemetry_api";
          sha256 = "b9e5ff775fd064fa098dba3c398490b77649a352b40b0b730a6b7dc0bdd68858";
        };

        beamDeps = [ opentelemetry_semantic_conventions ];
      };

    opentelemetry_exporter =
      let
        version = "1.7.0";
      in
      buildRebar3 {
        inherit version;
        name = "opentelemetry_exporter";

        src = fetchHex {
          inherit version;
          pkg = "opentelemetry_exporter";
          sha256 = "d0f25f6439ec43f2561537c3fabbe177b38547cddaa3a692cbb8f4770dbefc1e";
        };

        beamDeps = [ grpcbox opentelemetry opentelemetry_api tls_certificate_check ];
      };

    opentelemetry_semantic_conventions =
      let
        version = "0.2.0";
      in
      buildMix {
        inherit version;
        name = "opentelemetry_semantic_conventions";

        src = fetchHex {
          inherit version;
          pkg = "opentelemetry_semantic_conventions";
          sha256 = "d61fa1f5639ee8668d74b527e6806e0503efc55a42db7b5f39939d84c07d6895";
        };
      };

    plug =
      let
        version = "1.15.3";
      in
      buildMix {
        inherit version;
        name = "plug";

        src = fetchHex {
          inherit version;
          pkg = "plug";
          sha256 = "cc4365a3c010a56af402e0809208873d113e9c38c401cabd88027ef4f5c01fd2";
        };

        beamDeps = [ mime plug_crypto telemetry ];
      };

    plug_crypto =
      let
        version = "2.0.0";
      in
      buildMix {
        inherit version;
        name = "plug_crypto";

        src = fetchHex {
          inherit version;
          pkg = "plug_crypto";
          sha256 = "53695bae57cc4e54566d993eb01074e4d894b65a3766f1c43e2c61a1b0f45ea9";
        };
      };

    png =
      let
        version = "0.2.1";
      in
      buildRebar3 {
        inherit version;
        name = "png";

        src = fetchHex {
          inherit version;
          pkg = "png";
          sha256 = "279345e07108c604871a21f1c91f716810ab559af2b20d6f302e0a98265ef72e";
        };
      };

    postgrex =
      let
        version = "0.17.5";
      in
      buildMix {
        inherit version;
        name = "postgrex";

        src = fetchHex {
          inherit version;
          pkg = "postgrex";
          sha256 = "50b8b11afbb2c4095a3ba675b4f055c416d0f3d7de6633a595fc131a828a67eb";
        };

        beamDeps = [ db_connection decimal jason table ];
      };

    req =
      let
        version = "0.5.1";
      in
      buildMix {
        inherit version;
        name = "req";

        src = fetchHex {
          inherit version;
          pkg = "req";
          sha256 = "7ea96a1a95388eb0fefa92d89466cdfedba24032794e5c1147d78ec90db7edca";
        };

        beamDeps = [ finch jason mime plug ];
      };

    rustler =
      let
        version = "0.34.0";
      in
      buildMix {
        inherit version;
        name = "rustler";

        src = fetchHex {
          inherit version;
          pkg = "rustler";
          sha256 = "1d0c7449482b459513003230c0e2422b0252245776fe6fd6e41cb2b11bd8e628";
        };

        beamDeps = [ jason req toml ];
      };

    rustler_precompiled =
      let
        version = "0.8.0";
      in
      buildMix {
        inherit version;
        name = "rustler_precompiled";

        src = fetchHex {
          inherit version;
          pkg = "rustler_precompiled";
          sha256 = "00b1711d8d828200fe931e23bb0e72c2672a3a0ef76740e3c50433afda1965fb";
        };

        beamDeps = [ castore rustler ];
      };

    ssl_verify_fun =
      let
        version = "1.1.7";
      in
      buildMix {
        inherit version;
        name = "ssl_verify_fun";

        src = fetchHex {
          inherit version;
          pkg = "ssl_verify_fun";
          sha256 = "fe4c190e8f37401d30167c8c405eda19469f34577987c76dde613e838bbc67f8";
        };
      };

    table =
      let
        version = "0.1.2";
      in
      buildMix {
        inherit version;
        name = "table";

        src = fetchHex {
          inherit version;
          pkg = "table";
          sha256 = "7e99bc7efef806315c7e65640724bf165c3061cdc5d854060f74468367065029";
        };
      };

    table_rex =
      let
        version = "4.0.0";
      in
      buildMix {
        inherit version;
        name = "table_rex";

        src = fetchHex {
          inherit version;
          pkg = "table_rex";
          sha256 = "c35c4d5612ca49ebb0344ea10387da4d2afe278387d4019e4d8111e815df8f55";
        };
      };

    telemetry =
      let
        version = "1.2.1";
      in
      buildRebar3 {
        inherit version;
        name = "telemetry";

        src = fetchHex {
          inherit version;
          pkg = "telemetry";
          sha256 = "dad9ce9d8effc621708f99eac538ef1cbe05d6a874dd741de2e689c47feafed5";
        };
      };

    thousand_island =
      let
        version = "1.3.5";
      in
      buildMix {
        inherit version;
        name = "thousand_island";

        src = fetchHex {
          inherit version;
          pkg = "thousand_island";
          sha256 = "2be6954916fdfe4756af3239fb6b6d75d0b8063b5df03ba76fd8a4c87849e180";
        };

        beamDeps = [ telemetry ];
      };

    tls_certificate_check =
      let
        version = "1.22.1";
      in
      buildRebar3 {
        inherit version;
        name = "tls_certificate_check";

        src = fetchHex {
          inherit version;
          pkg = "tls_certificate_check";
          sha256 = "3092be0babdc0e14c2e900542351e066c0fa5a9cf4b3597559ad1e67f07938c0";
        };

        beamDeps = [ ssl_verify_fun ];
      };

    tokenizers =
      let
        version = "0.3.2";
      in
      buildMix {
        inherit version;
        name = "tokenizers";

        src = fetchHex {
          inherit version;
          pkg = "tokenizers";
          sha256 = "f6dd9a798e81cf2f3359e1731836ed0a351cae4da5d5d570a7ef3d0543e9cf85";
        };

        beamDeps = [ castore rustler rustler_precompiled ];
      };

    toml =
      let
        version = "0.7.0";
      in
      buildMix {
        inherit version;
        name = "toml";

        src = fetchHex {
          inherit version;
          pkg = "toml";
          sha256 = "0690246a2478c1defd100b0c9b89b4ea280a22be9a7b313a8a058a2408a2fa70";
        };
      };

    websock =
      let
        version = "0.5.3";
      in
      buildMix {
        inherit version;
        name = "websock";

        src = fetchHex {
          inherit version;
          pkg = "websock";
          sha256 = "6105453d7fac22c712ad66fab1d45abdf049868f253cf719b625151460b8b453";
        };
      };
  };
in
self
