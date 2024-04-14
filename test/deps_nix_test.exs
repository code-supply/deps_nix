defmodule DepsNixTest do
  use ExUnit.Case
  use ExUnitProperties

  alias DepsNix.Derivation
  alias DepsNix.FetchHex

  import TestHelpers

  property "sets unpackPhase for packages needing dir name to match package name" do
    check all name <- one_of([:grpcbox, :png]),
              version <- version(),
              dep <- dep(name: name, version: version) do
      expected_unpack_phase = """
      runHook preUnpack
      unpackFile "$src"
      chmod -R u+w -- hex-source-#{name}-#{version}
      mv hex-source-#{name}-#{version} #{name}
      sourceRoot=#{name}
      runHook postUnpack
      """

      assert %Derivation{unpack_phase: ^expected_unpack_phase} = DepsNix.transform(dep)
    end
  end

  property "prefers mix over every other builder" do
    check all dep <- dep(),
              :mix in builders_from(dep) do
      assert %Derivation{builder: "buildMix"} = DepsNix.transform(dep)
    end
  end

  property "prefers rebar3 when mix not available" do
    check all dep <- dep(builders: List.delete(DepsNix.builders(), :mix)),
              :rebar3 in builders_from(dep) do
      {:hex, _name, version, _hash, _beam_builders, _sub_deps, _, sha256} = dep.opts[:lock]

      expected_name = dep.app

      assert %Derivation{
               builder: "buildRebar3",
               name: ^expected_name,
               version: ^version,
               src: %FetchHex{
                 pkg: ^expected_name,
                 version: ^version,
                 sha256: ^sha256
               }
             } = DepsNix.transform(dep)
    end
  end

  test "doesn't include optional dependencies in beamDeps" do
    eventstore =
      %Mix.Dep{
        app: :eventstore,
        opts: [
          app_properties: [
            optional_applications: [:jason, :poolboy],
            applications: [
              :kernel,
              :stdlib,
              :elixir,
              :crypto,
              :eex,
              :logger,
              :ssl,
              :fsm,
              :gen_stage,
              :postgrex,
              :jason,
              :poolboy
            ]
          ],
          lock:
            {:hex, :eventstore, "1.4.4",
             "0b1e0f4af9f034210e24eb6a787006f52c3320baa863a7059d07e88654ef4334", [:mix],
             [
               {:fsm, "~> 0.3", [hex: :fsm, repo: "hexpm", optional: false]},
               {:gen_stage, "~> 1.2", [hex: :gen_stage, repo: "hexpm", optional: false]},
               {:jason, "~> 1.4", [hex: :jason, repo: "hexpm", optional: true]},
               {:poolboy, "~> 1.5", [hex: :poolboy, repo: "hexpm", optional: true]},
               {:postgrex, "~> 0.17", [hex: :postgrex, repo: "hexpm", optional: false]}
             ], "hexpm", "1cb0b76199dccff9625c2317b4500f51016c7ef6010c0de60e5f89bc6f8cb811"},
          env: :prod,
          hex: "eventstore",
          repo: "hexpm"
        ],
        deps: [
          %Mix.Dep{app: :fsm},
          %Mix.Dep{app: :gen_stage},
          %Mix.Dep{app: :postgrex}
        ],
        top_level: true,
        manager: :mix,
        system_env: []
      }

    assert DepsNix.transform(eventstore).beam_deps == [:fsm, :gen_stage, :postgrex]
  end

  test "uses app name as nix variable and derivation name" do
    chatterbox = %Mix.Dep{
      scm: Hex.SCM,
      app: :chatterbox,
      requirement: "~> 0.15.1",
      status: {:ok, "0.15.1"},
      opts: [
        lock:
          {:hex, :ts_chatterbox, "0.15.1",
           "5cac4d15dd7ad61fc3c4415ce4826fc563d4643dee897a558ec4ea0b1c835c9c", [:rebar3],
           [{:hpack, "~> 0.3.0", [hex: :hpack_erl, repo: "hexpm", optional: false]}], "hexpm",
           "4f75b91451338bc0da5f52f3480fa6ef6e3a2aeecfc33686d6b3d0a0948f31aa"},
        env: :prod,
        hex: "ts_chatterbox",
        repo: "hexpm",
        optional: false
      ],
      deps: [
        %Mix.Dep{
          app: :hpack
        }
      ],
      manager: :rebar3
    }

    assert DepsNix.transform(chatterbox) == %Derivation{
             builder: "buildRebar3",
             name: :chatterbox,
             version: "0.15.1",
             src: %FetchHex{
               pkg: :ts_chatterbox,
               version: "0.15.1",
               sha256: "4f75b91451338bc0da5f52f3480fa6ef6e3a2aeecfc33686d6b3d0a0948f31aa"
             },
             beam_deps: [:hpack]
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

  test "attempting to indent nil results in an empty string" do
    assert DepsNix.indent(nil) == ""
  end

  defp builders_from(%Mix.Dep{} = dep) do
    {:hex, _name, _version, _hash, builders, _sub_deps, _, _sha256} = dep.opts[:lock]
    builders
  end
end
