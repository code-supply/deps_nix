defmodule RunTest do
  use ExUnit.Case
  use ExUnitProperties

  alias DepsNix.Run

  import TestHelpers

  describe "argument parsing" do
    test "defaults to prod env" do
      assert Run.parse_args(~w()) == [env: :prod]
    end

    test "can pick up a single env" do
      assert Run.parse_args(~w(--env dev)) == [env: :dev]
    end

    test "made-up envs are ignored" do
      assert Run.parse_args(~w(--env poop)) == [env: :prod]
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

      assert Run.call(converger, env: :prod) =~ ~s( #{prod_dep.app} = build)
      refute Run.call(converger, env: :prod) =~ ~s( #{dev_dep.app} = build)

      assert Run.call(converger, env: :dev) =~ ~s( #{dev_dep.app} = build)
      assert Run.call(converger, env: :dev) =~ ~s( #{prod_dep.app} = build)
    end
  end
end
