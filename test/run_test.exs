defmodule RunTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias DepsNix.Run

  import TestHelpers

  describe "argument parsing" do
    test "defaults to prod env" do
      assert Run.parse_args(~w()) == %Run.Options{envs: %{"prod" => :all}}
    end

    test "can pick up a single env" do
      assert Run.parse_args(~w(--env dev)) == %Run.Options{envs: %{"dev" => :all}}
    end

    test "can choose an output path" do
      assert Run.parse_args(~w(--output foo/bar/deps.nix)) == %Run.Options{
               output: "foo/bar/deps.nix"
             }
    end

    property "can specify extra packages from a different environment" do
      check all package_names <- list_of(package_name()) do
        assert Run.parse_args(~w(--env prod --env dev=#{Enum.join(package_names, ",")})) ==
                 %Run.Options{
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
    converger = fn _ -> [] end

    assert {"my/path.nix", _} =
             Run.call(%Run.Options{output: "my/path.nix"}, converger)
  end

  test "can add packages and their dependency trees to a base environment" do
    sub_sub_dep = dep(name: :sub_sub_dep_thing) |> pick()
    sub_dep = dep(name: :sub_dep_thing, sub_deps: [sub_sub_dep]) |> pick()
    included_dev_dep = dep(name: :dev_dep_1, sub_deps: [sub_dep]) |> pick()
    excluded_dev_dep = dep(name: :excluded_dev_dep) |> pick()

    prod_git_dep =
      dep(
        name: :prod_thing,
        scm: Mix.SCM.Git,
        git_url: "https://gitstub.biz/awesome/project",
        version: "1.2.3"
      )
      |> pick()

    converger = fn
      # sub_dep included in both envs to ensure deduplication
      [env: :prod] ->
        [prod_git_dep, sub_dep]

      [env: :dev] ->
        [prod_git_dep, included_dev_dep, excluded_dev_dep, sub_dep, sub_sub_dep]
    end

    nix =
      output(
        %Run.Options{
          envs: %{"prod" => :all, "dev" => ["#{included_dev_dep.app}"]}
        },
        converger
      )

    assert Regex.scan(~r( #{prod_git_dep.app} =), nix) |> length() == 1,
           "Can't find #{prod_git_dep.app}'s build in: #{nix}"

    assert Regex.scan(~r( #{included_dev_dep.app} =), nix) |> length() == 1
    assert Regex.scan(~r( #{sub_dep.app} =), nix) |> length() == 1
    assert Regex.scan(~r( #{sub_sub_dep.app} =), nix) |> length() == 1
    assert Regex.scan(~r( #{excluded_dev_dep.app} =), nix) |> length() == 0
  end

  test "can choose environment to include" do
    check all prod_dep <- dep(),
              dev_dep <- dep(),
              prod_dep.app != dev_dep.app do
      converger = fn
        [env: :prod] ->
          [prod_dep]

        [env: :dev] ->
          [prod_dep, dev_dep]
      end

      assert output(%Run.Options{envs: %{"prod" => :all}}, converger) =~
               ~s( #{prod_dep.app} =)

      refute output(%Run.Options{envs: %{"prod" => :all}}, converger) =~
               ~s( #{dev_dep.app} =)

      assert output(%Run.Options{envs: %{"dev" => :all}}, converger) =~
               ~s( #{dev_dep.app} =)

      assert output(%Run.Options{envs: %{"dev" => :all}}, converger) =~
               ~s( #{prod_dep.app} =)
    end
  end

  test "output ends with a newline, for compatibility with other UNIX tools" do
    assert output(%Run.Options{}, fn _ -> [dep()] end) =~ ~r/\n$/
  end

  defp output(opts, converger) do
    {_path, output} = Run.call(opts, converger)
    output
  end
end
