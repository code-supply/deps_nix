defmodule DepsNixTest do
  use ExUnit.Case

  alias DepsNix.Derivation
  alias DepsNix.FetchHex

  test "can indent a string" do
    assert DepsNix.indent("""
           hi
           there

           you
           """) == """
             hi
             there

             you
           """
  end

  test "can convert rebar3 dependencies" do
    telemetry = %Mix.Dep{
      scm: Hex.SCM,
      app: :telemetry,
      requirement: "~> 0.4 or ~> 1.0",
      status: {:ok, "1.2.1"},
      opts: [
        lock:
          {:hex, :telemetry, "1.2.1",
           "68fdfe8d8f05a8428483a97d7aab2f268aaff24b49e0f599faa091f1d4e7f61c", [:rebar3], [],
           "hexpm", "dad9ce9d8effc621708f99eac538ef1cbe05d6a874dd741de2e689c47feafed5"},
        env: :prod,
        hex: "telemetry",
        repo: "hexpm",
        optional: false
      ],
      deps: [],
      top_level: false,
      manager: :rebar3,
      system_env: []
    }

    assert DepsNix.transform(telemetry) == %Derivation{
             builder: "buildRebar3",
             name: :telemetry,
             version: "1.2.1",
             src: %FetchHex{
               pkg: :telemetry,
               version: "1.2.1",
               sha256: "dad9ce9d8effc621708f99eac538ef1cbe05d6a874dd741de2e689c47feafed5"
             },
             beam_deps: []
           }
  end

  test "can convert mix dependencies with sub dependencies" do
    bandit = %Mix.Dep{
      scm: Hex.SCM,
      app: :bandit,
      requirement: "~> 1.2",
      status: {:ok, "1.4.2"},
      opts: [
        lock:
          {:hex, :bandit, "1.4.2",
           "a1475c8dcbffd1f43002797f99487a64c8444753ff2b282b52409e279488e1f5", [:mix],
           [
             {:hpax, "~> 0.1.1", [hex: :hpax, repo: "hexpm", optional: false]},
             {:plug, "~> 1.14", [hex: :plug, repo: "hexpm", optional: false]},
             {:telemetry, "~> 0.4 or ~> 1.0", [hex: :telemetry, repo: "hexpm", optional: false]},
             {:thousand_island, "~> 1.0",
              [hex: :thousand_island, repo: "hexpm", optional: false]},
             {:websock, "~> 0.5", [hex: :websock, repo: "hexpm", optional: false]}
           ], "hexpm", "3db8bacea631bd926cc62ccad58edfee4252d1b4c5cccbbad9825df2722b884f"},
        env: :prod,
        hex: "bandit",
        repo: "hexpm"
      ],
      deps: [
        %Mix.Dep{app: :hpax},
        %Mix.Dep{app: :plug},
        %Mix.Dep{app: :telemetry},
        %Mix.Dep{app: :thousand_island},
        %Mix.Dep{app: :websock}
      ]
    }

    assert DepsNix.transform(bandit) == %Derivation{
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
  end
end
