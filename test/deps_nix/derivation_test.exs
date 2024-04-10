defmodule DepsNix.DerivationTest do
  use ExUnit.Case

  alias DepsNix.Derivation
  alias DepsNix.FetchHex

  describe "string representation" do
    test "is a Nix expression" do
      assert %Derivation{
               builder: "buildMix",
               name: :bandit,
               version: "1.4.2",
               src: %FetchHex{
                 pkg: :bandit,
                 version: "1.4.2",
                 sha256: "3db8bacea631bd926cc62ccad58edfee4252d1b4c5cccbbad9825df2722b884f"
               },
               beam_deps: [:hpax, :plug, :telemetry, :thousand_island, :websock]
             }
             |> to_string() == """
             bandit = buildMix rec {
               name = "bandit";
               version = "1.4.2";

               src = fetchHex {
                 pkg = "bandit";
                 version = "${version}";
                 sha256 = "3db8bacea631bd926cc62ccad58edfee4252d1b4c5cccbbad9825df2722b884f";
               };

               beamDeps = [ hpax plug telemetry thousand_island websock ];
             };
             """
    end

    test "converts unpack phase" do
      string_rep =
        %Derivation{
          builder: "buildMix",
          name: :bandit,
          version: "1.4.2",
          src: %FetchHex{
            pkg: :bandit,
            version: "1.4.2",
            sha256: "3db8bacea631bd926cc62ccad58edfee4252d1b4c5cccbbad9825df2722b884f"
          },
          beam_deps: [],
          unpack_phase: """
          echo "hi!"
          """
        }
        |> to_string()

      assert string_rep == """
             bandit = buildMix rec {
               name = "bandit";
               version = "1.4.2";

               src = fetchHex {
                 pkg = "bandit";
                 version = "${version}";
                 sha256 = "3db8bacea631bd926cc62ccad58edfee4252d1b4c5cccbbad9825df2722b884f";
               };

               beamDeps = [ ];

               unpackPhase = ''
                 echo "hi!"
               '';
             };
             """
    end

    test "empty sub-deps produce an empty list, formatted like nixpkgs-fmt" do
      assert %Derivation{
               builder: "buildMix",
               name: :bandit,
               version: "1.4.2",
               src: %FetchHex{
                 pkg: :bandit,
                 version: "1.4.2",
                 sha256: "3db8bacea631bd926cc62ccad58edfee4252d1b4c5cccbbad9825df2722b884f"
               },
               beam_deps: []
             }
             |> to_string() == """
             bandit = buildMix rec {
               name = "bandit";
               version = "1.4.2";

               src = fetchHex {
                 pkg = "bandit";
                 version = "${version}";
                 sha256 = "3db8bacea631bd926cc62ccad58edfee4252d1b4c5cccbbad9825df2722b884f";
               };

               beamDeps = [ ];
             };
             """
    end
  end
end
