defmodule DepsNix.DerivationTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias DepsNix.Derivation
  alias DepsNix.FetchFromGitHub
  alias DepsNix.FetchGit
  alias DepsNix.FetchHex
  alias DepsNix.Path

  import TestHelpers

  property "configures app config path based on cwd" do
    check all dep <- dep() do
      assert %Derivation{
               app_config_path: "../../config"
             } =
               Derivation.from(dep, %DepsNix.Options{
                 output: "some/place/deps.nix",
                 cwd: "/home/andrew/workspace/my_project/subdir/subproj"
               })
    end
  end

  property "translates dependencies specified with path" do
    check all dep <-
                dep(
                  scm: Mix.SCM.Path,
                  dep_opts: [
                    dest: "/Users/andrew.bruce/workspace/nrg/pkgs/infrastructure",
                    include_paths: true,
                    app_properties: [
                      vsn: ~c"0.1.2"
                    ]
                  ]
                ) do
      assert %Derivation{
               version: ~c"0.1.2",
               src: %Path{path: "../../infrastructure"}
             } =
               Derivation.from(
                 dep,
                 %DepsNix.Options{
                   output: "nix/deps.nix",
                   cwd: "/Users/andrew.bruce/workspace/nrg/pkgs/workbench"
                 }
               )
    end
  end

  property "translates dependencies specified with git" do
    check all url <- string(:alphanumeric),
              rev <- hash(),
              dep <- dep(scm: Mix.SCM.Git, git_url: url, version: rev) do
      assert %Derivation{
               src: %FetchGit{url: ^url, rev: ^rev}
             } = Derivation.from(dep, %DepsNix.Options{})
    end
  end

  property "translates GitHub dependencies to use fetchFromGitHub" do
    check all url <- url(host: "github", tld: "com", path: "/code-supply/mudbrick.git"),
              rev <- hash(),
              generated_hash <- hash(),
              dep <- dep(scm: Mix.SCM.Git, git_url: url, version: rev) do
      assert %Derivation{
               src: %FetchFromGitHub{
                 owner: "code-supply",
                 repo: "mudbrick",
                 rev: ^rev,
                 hash: ^generated_hash
               }
             } =
               Derivation.from(dep, %DepsNix.Options{
                 github_prefetcher: fn
                   "code-supply", "mudbrick", ^rev ->
                     {generated_hash, "buildMix"}
                 end
               })
    end
  end

  property "translates GitHub dependencies marked as private to use fetchGit" do
    check all url <- url(host: "github", tld: "com", path: "/code-supply/mudbrick.git"),
              rev <- hash(),
              dep <-
                dep(scm: Mix.SCM.Git, git_url: url, version: rev, dep_opts: [private: "true"]) do
      assert %Derivation{
               src: %FetchGit{url: ^url, rev: ^rev}
             } = Derivation.from(dep, %DepsNix.Options{})
    end
  end

  property "prefers mix over every other builder" do
    check all other_builders <- list_of(one_of([:make, :rebar3])),
              dep <- dep(builders: [:mix] ++ other_builders) do
      assert %Derivation{builder: "buildMix"} = Derivation.from(dep, %DepsNix.Options{})
    end
  end

  property "prefers rebar3 for hex SCM when mix not available" do
    check all dep <- dep(scm: Mix.SCM.Hex, builders: [:rebar3, :make]) do
      expected_name = dep.app

      assert %Derivation{
               builder: "buildRebar3",
               name: ^expected_name
             } = Derivation.from(dep, %DepsNix.Options{})
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

    assert Derivation.from(eventstore, %DepsNix.Options{}).beam_deps == [
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

    assert Derivation.from(chatterbox, %DepsNix.Options{}) == %Derivation{
             builder: "buildRebar3",
             name: :chatterbox,
             version: "0.15.1",
             src: %FetchHex{
               pkg: :ts_chatterbox,
               version: "0.15.1",
               sha256: "4f75b91451338bc0da5f52f3480fa6ef6e3a2aeecfc33686d6b3d0a0948f31aa"
             },
             beam_deps: [:hpack],
             app_config_path: "config"
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

    assert Derivation.from(bandit, %DepsNix.Options{}) == %Derivation{
             builder: "buildMix",
             name: :bandit,
             version: "1.4.2",
             src: %FetchHex{
               pkg: :bandit,
               version: "1.4.2",
               sha256: "3db8bacea631bd926cc62ccad58edfee4252d1b4c5cccbbad9825df2722b884f"
             },
             beam_deps: [:hpax, :plug, :telemetry, :thousand_island, :websock],
             app_config_path: "config"
           }
  end

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
               beam_deps: [:hpax, :plug, :telemetry, :thousand_island, :websock],
               app_config_path: "foo"
             }
             |> to_string() == """
             bandit =
               let
                 version = "1.4.2";
                 drv = buildMix {
                   inherit version;
                   name = "bandit";
                   appConfigPath = ./foo;

                   src = fetchHex {
                     inherit version;
                     pkg = "bandit";
                     sha256 = "3db8bacea631bd926cc62ccad58edfee4252d1b4c5cccbbad9825df2722b884f";
                   };

                   beamDeps = [
                     hpax
                     plug
                     telemetry
                     thousand_island
                     websock
                   ];
                 };
               in
               drv;
             """
    end

    test "is just a fetcher for heroicons" do
      assert %Derivation{
               builder: "buildMix",
               name: :heroicons,
               version: "6.6.6",
               src: %FetchFromGitHub{
                 owner: "tailwindlabs",
                 repo: "heroicons",
                 rev: "88ab3a0d790e6a47404cba02800a6b25d2afae50",
                 hash: "sha256-4yRqfY8r2Ar9Fr45ikD/8jK+H3g4veEHfXa9BorLxXg="
               },
               beam_deps: [],
               app_config_path: "foo"
             }
             |> to_string() == """
             heroicons = pkgs.fetchFromGitHub {
               owner = "tailwindlabs";
               repo = "heroicons";
               rev = "88ab3a0d790e6a47404cba02800a6b25d2afae50";
               hash = "sha256-4yRqfY8r2Ar9Fr45ikD/8jK+H3g4veEHfXa9BorLxXg=";
             };
             """
    end

    test "rebar3 builds don't get appConfigPaths" do
      refute dep(builders: [:rebar3], scm: Mix.SCM.Hex)
             |> pick()
             |> Derivation.from(%DepsNix.Options{})
             |> to_string()
             |> String.contains?("appConfigPath")
    end

    test "paths get special treatment" do
      assert %Derivation{
               builder: "buildMix",
               name: :my_project,
               version: "6.6.6",
               src: %Path{
                 path: "../in/ur/repoz"
               },
               beam_deps: [:hpax, :plug, :telemetry, :thousand_island, :websock],
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

                   src = ../in/ur/repoz;


                   beamDeps = [
                     hpax
                     plug
                     telemetry
                     thousand_island
                     websock
                   ];
                 };
               in
               drv;
             """
    end

    test "empty sub-deps produce an empty list, formatted like nixfmt" do
      assert %Derivation{
               builder: "buildMix",
               name: :bandit,
               version: "1.4.2",
               src: %FetchHex{
                 pkg: :bandit,
                 version: "1.4.2",
                 sha256: "3db8bacea631bd926cc62ccad58edfee4252d1b4c5cccbbad9825df2722b884f"
               },
               beam_deps: [],
               app_config_path: "config"
             }
             |> to_string() == """
             bandit =
               let
                 version = "1.4.2";
                 drv = buildMix {
                   inherit version;
                   name = "bandit";
                   appConfigPath = ./config;

                   src = fetchHex {
                     inherit version;
                     pkg = "bandit";
                     sha256 = "3db8bacea631bd926cc62ccad58edfee4252d1b4c5cccbbad9825df2722b884f";
                   };
                 };
               in
               drv;
             """
    end
  end
end
