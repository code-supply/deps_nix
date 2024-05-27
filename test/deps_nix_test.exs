defmodule DepsNixTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias DepsNix.Derivation
  alias DepsNix.FetchGit
  alias DepsNix.FetchHex

  import TestHelpers

  describe "argument parsing" do
    test "defaults to prod env" do
      assert DepsNix.parse_args(~w()) == %DepsNix.Options{envs: %{"prod" => :all}}
    end

    test "can pick up a single env" do
      assert DepsNix.parse_args(~w(--env dev)) == %DepsNix.Options{envs: %{"dev" => :all}}
    end

    test "can choose an output path" do
      assert DepsNix.parse_args(~w(--output foo/bar/deps.nix)) == %DepsNix.Options{
               output: "foo/bar/deps.nix"
             }
    end

    property "can specify extra packages from a different environment" do
      check all package_names <- list_of(package_name()), max_runs: 10 do
        assert DepsNix.parse_args(~w(--env prod --env dev=#{Enum.join(package_names, ",")})) ==
                 %DepsNix.Options{
                   envs: %{
                     "prod" => :all,
                     "dev" => package_names
                   }
                 }
      end
    end

    defp package_name do
      string(:alphanumeric, min_length: 1)
    end
  end

  test "sets path from options" do
    assert {"my/path.nix", _} =
             DepsNix.run(%DepsNix.Options{output: "my/path.nix"}, &stub_converger/1)
  end

  test "empty deps list formats output correctly" do
    assert output(%DepsNix.Options{}, &stub_converger/1) =~ "with self; { };"
  end

  test "can add packages and their dependency trees to a base environment" do
    sub_sub_dep = dep(name: :sub_sub_dep_thing) |> pick()
    sub_dep = dep(name: :sub_dep_thing, sub_deps: [sub_sub_dep]) |> pick()
    included_dev_dep = dep(name: :dev_dep_1, sub_deps: [sub_dep]) |> pick()
    excluded_dev_dep = dep(name: :excluded_dev_dep) |> pick()
    prod_dep = dep(name: :prod_thing) |> pick()

    converger = fn
      # sub_dep included in both envs to ensure deduplication
      [env: :prod] ->
        [prod_dep, sub_dep]

      [env: :dev] ->
        [prod_dep, included_dev_dep, excluded_dev_dep, sub_dep, sub_sub_dep]
    end

    nix =
      output(
        %DepsNix.Options{
          envs: %{"prod" => :all, "dev" => ["#{included_dev_dep.app}"]}
        },
        converger
      )

    assert Regex.scan(~r( #{prod_dep.app} =), nix) |> length() == 1,
           "Expected to find 1 of #{prod_dep.app}'s build in: #{nix}"

    assert Regex.scan(~r( #{included_dev_dep.app} =), nix) |> length() == 1
    assert Regex.scan(~r( #{sub_dep.app} =), nix) |> length() == 1
    assert Regex.scan(~r( #{sub_sub_dep.app} =), nix) |> length() == 1
    assert Regex.scan(~r( #{excluded_dev_dep.app} =), nix) |> length() == 0
  end

  test "can choose environment to include" do
    [prod_dep, dev_dep] = pick(uniq_list_of(dep(), length: 2))

    converger = fn
      [env: :prod] ->
        [prod_dep]

      [env: :dev] ->
        [prod_dep, dev_dep]
    end

    assert output(%DepsNix.Options{envs: %{"prod" => :all}}, converger) =~
             ~s( #{prod_dep.app} =)

    refute output(%DepsNix.Options{envs: %{"prod" => :all}}, converger) =~
             ~s( #{dev_dep.app} =)

    assert output(%DepsNix.Options{envs: %{"dev" => :all}}, converger) =~
             ~s( #{dev_dep.app} =)

    assert output(%DepsNix.Options{envs: %{"dev" => :all}}, converger) =~
             ~s( #{prod_dep.app} =)
  end

  test "output ends with a newline, for compatibility with other UNIX tools" do
    assert output(%DepsNix.Options{}) =~ ~r/\n$/
  end

  defp output(opts, converger \\ &stub_converger/1) do
    {_path, output} = DepsNix.run(opts, converger)
    output
  end

  defp stub_converger(_), do: []

  property "translates dependencies specified with git" do
    check all url <- url(),
              rev <- hash(),
              dep <- dep(scm: Mix.SCM.Git, git_url: url, version: rev) do
      assert %Derivation{
               src: %FetchGit{url: ^url, rev: ^rev}
             } = Derivation.from(dep)
    end
  end

  property "prefers mix over every other builder" do
    check all other_builders <- list_of(one_of([:make, :rebar3])),
              dep <- dep(builders: [:mix] ++ other_builders) do
      assert %Derivation{builder: "buildMix"} = Derivation.from(dep)
    end
  end

  property "prefers rebar3 for hex SCM when mix not available" do
    check all dep <- dep(scm: Mix.SCM.Hex, builders: [:rebar3, :make]) do
      expected_name = dep.app

      assert %Derivation{
               builder: "buildRebar3",
               name: ^expected_name
             } = Derivation.from(dep)
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

    assert Derivation.from(eventstore).beam_deps == [
             :fsm,
             :gen_stage,
             :postgrex
           ]
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

    assert Derivation.from(chatterbox) == %Derivation{
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

    assert Derivation.from(bandit) == %Derivation{
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
