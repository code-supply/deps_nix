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
             Run.call(%Run.Options{output: "my/path.nix"}, converger, prefetcher_stub())
  end

  test "can add packages and their dependency trees to a base environment" do
    check all [prod_dep_name, dev_dep_1_name, sub_dep_name, sub_sub_dep_name, dev_dep_2_name] <-
                uniq_list_of(atom(:alphanumeric), length: 5),
              prod_dep <- dep(name: prod_dep_name),
              sub_sub_dep <- dep(name: sub_sub_dep_name),
              sub_dep <- dep(name: sub_dep_name, sub_deps: [sub_sub_dep]),
              included_dev_dep <- dep(name: dev_dep_1_name, sub_deps: [sub_dep]),
              excluded_dev_dep <- dep(name: dev_dep_2_name) do
      converger = fn
        # sub_dep included in both envs to ensure deduplication
        [env: :prod] ->
          [prod_dep, sub_dep]

        [env: :dev] ->
          [prod_dep, included_dev_dep, excluded_dev_dep, sub_dep, sub_sub_dep]
      end

      prefetcher = fn url, rev -> ~s({ "hash": "stubbed-hash-for-#{url}-#{rev}" }) end

      nix =
        output(
          %Run.Options{
            envs: %{"prod" => :all, "dev" => ["#{included_dev_dep.app}"]}
          },
          converger,
          prefetcher
        )

      assert Regex.scan(~r( #{prod_dep.app} = build), nix) |> length() == 1
      assert Regex.scan(~r( #{included_dev_dep.app} = build), nix) |> length() == 1
      assert Regex.scan(~r( #{sub_dep.app} = build), nix) |> length() == 1
      assert Regex.scan(~r( #{sub_sub_dep.app} = build), nix) |> length() == 1
      assert Regex.scan(~r( #{excluded_dev_dep.app} = build), nix) |> length() == 0

      [prod_dep, included_dev_dep, sub_dep, sub_sub_dep]
      |> Enum.filter(&(&1.scm == Mix.SCM.Git))
      |> Enum.each(fn dep ->
        {:git, url, rev, _} = dep.opts[:lock]
        assert nix =~ "stubbed-hash-for-#{url}-#{rev}"
      end)
    end
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
               ~s( #{prod_dep.app} = build)

      refute output(%Run.Options{envs: %{"prod" => :all}}, converger) =~
               ~s( #{dev_dep.app} = build)

      assert output(%Run.Options{envs: %{"dev" => :all}}, converger) =~
               ~s( #{dev_dep.app} = build)

      assert output(%Run.Options{envs: %{"dev" => :all}}, converger) =~
               ~s( #{prod_dep.app} = build)
    end
  end

  defp output(opts, converger, prefetcher \\ prefetcher_stub()) do
    {_path, output} = Run.call(opts, converger, prefetcher)
    output
  end
end
