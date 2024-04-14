defmodule RunTest do
  use ExUnit.Case
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

  test "can add packages and their dependency trees to a base environment" do
    check all [prod_dep_name, dev_dep_1_name, sub_dep_name, sub_sub_dep_name, dev_dep_2_name] <-
                uniq_list_of(atom(:alphanumeric), length: 5),
              prod_dep <- dep(name: prod_dep_name),
              sub_sub_dep <- dep(name: sub_sub_dep_name),
              sub_dep <- dep(name: sub_dep_name, sub_deps: [sub_sub_dep]),
              dev_dep_1 <- dep(name: dev_dep_1_name, sub_deps: [sub_dep]),
              dev_dep_2 <- dep(name: dev_dep_2_name) do
      converger = fn
        # sub_dep included in both envs to ensure deduplication
        [env: :prod] ->
          [prod_dep, sub_dep]

        [env: :dev] ->
          [prod_dep, dev_dep_1, dev_dep_2, sub_dep, sub_sub_dep]
      end

      nix =
        output(converger, %Run.Options{
          envs: %{"prod" => :all, "dev" => ["#{dev_dep_1.app}"]}
        })

      assert Regex.scan(~r( #{prod_dep.app} = build), nix) |> length() == 1
      assert Regex.scan(~r( #{dev_dep_1.app} = build), nix) |> length() == 1
      assert Regex.scan(~r( #{sub_dep.app} = build), nix) |> length() == 1
      assert Regex.scan(~r( #{sub_sub_dep.app} = build), nix) |> length() == 1
      assert Regex.scan(~r( #{dev_dep_2.app} = build), nix) |> length() == 0
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

      assert output(converger, %Run.Options{envs: %{"prod" => :all}}) =~
               ~s( #{prod_dep.app} = build)

      refute output(converger, %Run.Options{envs: %{"prod" => :all}}) =~
               ~s( #{dev_dep.app} = build)

      assert output(converger, %Run.Options{envs: %{"dev" => :all}}) =~
               ~s( #{dev_dep.app} = build)

      assert output(converger, %Run.Options{envs: %{"dev" => :all}}) =~
               ~s( #{prod_dep.app} = build)
    end
  end

  defp output(converger, opts) do
    {_path, output} = Run.call(converger, opts)
    output
  end
end
