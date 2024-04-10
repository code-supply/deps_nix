defmodule DepsNixTest do
  use ExUnit.Case
  use ExUnitProperties

  alias DepsNix.Derivation
  alias DepsNix.FetchHex

  property "sets unpackPhase for packages needing dir name to match package name" do
    check all name <- one_of([:grpcbox]),
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

      assert DepsNix.transform(dep) == %Derivation{
               builder: "buildRebar3",
               name: dep.app,
               version: version,
               src: %FetchHex{
                 pkg: dep.app,
                 version: version,
                 sha256: sha256
               },
               beam_deps: []
             }
    end
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

  defp version do
    gen all major <- non_negative_integer(),
            minor <- non_negative_integer(),
            patch <- non_negative_integer() do
      "#{major}.#{minor}.#{patch}"
    end
  end

  defp dep(opts \\ []) do
    builders = Keyword.get(opts, :builders, DepsNix.builders())
    name_gen = Keyword.get(opts, :name, atom(:alphanumeric))
    version = Keyword.get(opts, :version, version())

    gen all name <- name_gen,
            hash1 <- string(:alphanumeric, length: 64),
            hash2 <- string(:alphanumeric, length: 64) do
      %Mix.Dep{
        app: name,
        opts: [
          lock: {:hex, name, version, hash1, builders, [], "hexpm", hash2},
          env: :prod
        ]
      }
    end
  end
end
