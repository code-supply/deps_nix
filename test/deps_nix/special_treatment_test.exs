defmodule DepsNix.SpecialTreatmentTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias DepsNix.Derivation
  alias DepsNix.FetchHex

  test "unicode uses a custom directory for its data" do
    assert %Derivation{
             builder: "buildMix",
             name: :unicode,
             version: "1.2.3",
             src: %FetchHex{
               pkg: :unicode,
               version: "1.2.3",
               sha256: "xxx"
             },
             beam_deps: [],
             app_config_path: "./config"
           }
           |> to_string() ==
             """
             unicode =
               let
                 version = "1.2.3";
                 drv = buildMix {
                   inherit version;
                   name = "unicode";
                   appConfigPath = ./config;

                   src = fetchHex {
                     inherit version;
                     pkg = "unicode";
                     sha256 = "xxx";
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
             """
  end

  test "unicode_string has access to unicode's source at compile time" do
    assert %Derivation{
             builder: "buildMix",
             name: :unicode_string,
             version: "1.2.3",
             src: %FetchHex{
               pkg: :unicode_string,
               version: "1.2.3",
               sha256: "xxx"
             },
             beam_deps: [
               :ex_cldr,
               :jason,
               :sweet_xml,
               :trie,
               :unicode,
               :unicode_set
             ],
             app_config_path: "./config"
           }
           |> to_string() ==
             """
             unicode_string =
               let
                 version = "1.2.3";
                 drv = buildMix {
                   inherit version;
                   name = "unicode_string";
                   appConfigPath = ./config;

                   src = fetchHex {
                     inherit version;
                     pkg = "unicode_string";
                     sha256 = "xxx";
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
             """
  end

  test "vix gets the vips dependency provided from nixpkgs" do
    assert %Derivation{
             builder: "buildMix",
             name: :vix,
             version: "0.33.0",
             src: %FetchHex{
               pkg: :vix,
               version: "0.33.0",
               sha256: "9acde72b27bdfeadeb51f790f7a6cc0d06cf555718c05cf57e43c5cf93d8471b"
             },
             beam_deps: [
               :castore,
               :cc_precompiler,
               :elixir_make
             ],
             app_config_path: "./config"
           }
           |> to_string() == """
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
           """
  end

  test "rustler_precompiled dependencies get automatically overridden" do
    assert %Derivation{
             builder: "buildMix",
             name: :my_project,
             version: "6.6.6",
             src: %FetchHex{
               pkg: :my_project,
               version: "6.6.6",
               sha256: "3db8bacea631bd926cc62ccad58edfee4252d1b4c5cccbbad9825df2722b884f"
             },
             beam_deps: [:rustler_precompiled, :some_other_dep],
             app_config_path: "../../config"
           }
           |> to_string() == """
           my_project =
             let
               version = "6.6.6";
               drv = buildMix {
                 inherit version;
                 name = "my_project";
                 appConfigPath = ../../config;

                 src = fetchHex {
                   inherit version;
                   pkg = "my_project";
                   sha256 = "3db8bacea631bd926cc62ccad58edfee4252d1b4c5cccbbad9825df2722b884f";
                 };

                 beamDeps = [
                   rustler_precompiled
                   some_other_dep
                 ];
               };
             in
             drv.override (workarounds.rustlerPrecompiled { } drv);
           """
  end
end
