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

      assert Run.call(converger, %Run.Options{envs: %{"prod" => :all}}) =~
               ~s( #{prod_dep.app} = build)

      refute Run.call(converger, %Run.Options{envs: %{"prod" => :all}}) =~
               ~s( #{dev_dep.app} = build)

      assert Run.call(converger, %Run.Options{envs: %{"dev" => :all}}) =~
               ~s( #{dev_dep.app} = build)

      assert Run.call(converger, %Run.Options{envs: %{"dev" => :all}}) =~
               ~s( #{prod_dep.app} = build)
    end
  end
end
