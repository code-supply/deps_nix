defmodule DepsNixTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import TestHelpers

  describe "prefetching GitHub hash" do
    test "works for this repo" do
      assert DepsNix.github_prefetcher(
               "code-supply",
               "deps_nix",
               "8a6c3537c958fe3fd1810d56bdee6c13fb35d089"
             ) == {"sha256-zJOkGOSBBA0Y9HPRmwPmBpqaqsoRa0oR7VjMMyukvX4=", "buildMix"}
    end

    test "works for repos with ../ relative symlinks" do
      assert DepsNix.github_prefetcher(
               "Strech",
               "avrora",
               "a2df4d8f177dacc7be24aa3e6bc76b52c3f114a9"
             ) == {"sha256-msktKtQGBhe2UrZr9uiKiRFCiXCkFa0+zbOy8KQIhc4=", "buildMix"}
    end

    test "detects rebar3-only repositories" do
      assert DepsNix.github_prefetcher(
               "klarna",
               "mnesia_eleveldb",
               "af6d0556a78aec2918b3471f0c85121402a1f5b1"
             ) == {"sha256-+ZZ5Uyoe/HK0wL0ev1vn9Tuiaps4X88izETtuRszKYE=", "buildRebar3"}
    end

    test "prefers buildMix over buildRebar3 for repos that have both" do
      assert DepsNix.github_prefetcher(
               "erlef",
               "oidcc",
               "fdf45b06d79813c7110171c5c6d334394c2f1190"
             ) == {"sha256-QUwRH9GWMTrG2HsFqiPNNKm+K5+cwPigdtlx9OUNK58=", "buildMix"}
    end

    test "fails for nonsense repos" do
      assert_raise(DepsNix.InvalidGitHubReference, fn ->
        DepsNix.github_prefetcher(
          "not",
          "theright",
          "args"
        )
      end)
    end
  end

  describe "argument parsing" do
    test "defaults to prod env" do
      assert %DepsNix.Options{envs: %{"prod" => :all}} = DepsNix.parse_args(~w())
    end

    test "can pick up a single env" do
      assert %DepsNix.Options{envs: %{"dev" => :all}} = DepsNix.parse_args(~w(--env dev))
    end

    test "can choose an output path" do
      assert %DepsNix.Options{
               output: "foo/bar/deps.nix"
             } = DepsNix.parse_args(~w(--output foo/bar/deps.nix))
    end

    property "can specify extra packages from a different environment" do
      check all package_names <- list_of(package_name()), max_runs: 10 do
        assert %DepsNix.Options{
                 envs: %{
                   "prod" => :all,
                   "dev" => ^package_names
                 }
               } = DepsNix.parse_args(~w(--env prod --env dev=#{Enum.join(package_names, ",")}))
      end
    end

    test "can request inclusion of path dependencies" do
      assert %DepsNix.Options{
               envs: %{
                 "prod" => :all
               },
               include_paths: true
             } = DepsNix.parse_args(~w(--env prod --include-paths))
    end

    test "requesting inclusion of path dependencies doesn't affect default options" do
      assert %DepsNix.Options{
               envs: %{
                 "prod" => :all
               },
               include_paths: true
             } = DepsNix.parse_args(~w(--include-paths))
    end

    test "can specify application config directory path" do
      assert %DepsNix.Options{
               app_config_path: "../my/app/config"
             } = DepsNix.parse_args(~w(--app-config-path ../my/app/config))
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
    assert output(%DepsNix.Options{}, &stub_converger/1) =~ "with self;\n    {\n \n    };"
  end

  test "creates a special fetcher derivation for heroicons, which is included in new Phoenix apps" do
    dep = dep(name: :heroicons, dep_opts: [app: false, compile: false]) |> pick()
    converger = fn [env: :prod] -> [dep] end
    nix = output(%DepsNix.Options{envs: %{"prod" => :all}}, converger)

    assert Regex.scan(~r(heroicons), nix) |> length() >= 1,
           "Couldn't find special-cased heroicons fetcher in #{nix}"
  end

  property "doesn't create derivations marked both app: false and compile: false" do
    check all dep <- dep(name: :not_a_mix_dep, dep_opts: [app: false, compile: false]) do
      converger = fn [env: :prod] -> [dep] end
      nix = output(%DepsNix.Options{envs: %{"prod" => :all}}, converger)

      refute Regex.scan(~r(not_a_mix_dep), nix) |> length() >= 1,
             "Shouldn't be including app: false, compile: false dependencies, found #{dep.app}."
    end
  end

  describe "path dependencies" do
    test "are excluded by default" do
      dep = dep(name: :a_path_dep, scm: Mix.SCM.Path) |> pick()

      converger = fn
        [env: :prod] ->
          [dep]
      end

      nix = output(%DepsNix.Options{envs: %{"prod" => :all}}, converger)

      assert Regex.scan(~r(a_path_dep), nix) |> length() == 0,
             "Shouldn't be including :path dependencies, found #{dep.app}."
    end

    test "can be included" do
      dep =
        dep(
          name: :a_path_dep,
          scm: Mix.SCM.Path,
          dep_opts: [dest: "/home/andrew/workspace/great_project"]
        )
        |> pick()

      converger = fn
        [env: :prod] ->
          [dep]
      end

      nix =
        output(
          %DepsNix.Options{envs: %{"prod" => :all}, include_paths: true, cwd: "some/place"},
          converger
        )

      assert Regex.scan(~r(a_path_dep), nix) |> length() >= 1,
             "Should be including selected :path dependencies."
    end
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

  test "can specify appConfigPath" do
    converger = fn _ -> [pick(dep())] end

    assert output(
             %DepsNix.Options{
               envs: %{"prod" => :all},
               app_config_path: "../my/app/config"
             },
             converger
           ) =~
             ~s(appConfigPath = ../my/app/config;)
  end

  defp output(opts, converger \\ &stub_converger/1) do
    {_path, output} = DepsNix.run(opts, converger)
    output
  end

  defp stub_converger(_), do: []
end
