defmodule DepsNixTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

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

  property "doesn't create derivations marked both app: false and compile: false" do
    check all dep <- dep(name: :not_a_mix_dep, dep_opts: [app: false, compile: false]) do
      converger = fn [env: :prod] -> [dep] end
      nix = output(%DepsNix.Options{envs: %{"prod" => :all}}, converger)

      refute Regex.scan(~r(not_a_mix_dep), nix) |> length() >= 1,
             "Shouldn't be including app: false, compile: false dependencies, found #{dep.app}."
    end
  end

  test "doesn't create derivations for :path dependencies" do
    dep = dep(name: :a_path_dep, scm: Mix.SCM.Path) |> pick()

    converger = fn
      [env: :prod] ->
        [dep]
    end

    nix = output(%DepsNix.Options{envs: %{"prod" => :all}}, converger)

    refute Regex.scan(~r(a_path_dep), nix) |> length() >= 1,
           "Shouldn't be including :path dependencies, found #{dep.app}."
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
end
