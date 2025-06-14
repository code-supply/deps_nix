defmodule Mix.Tasks.Deps.NixTest do
  use ExUnit.Case, async: true

  @tag timeout: 240_000
  test "produces a formatted Nix function for the fixture app's dependencies" do
    {run_output, run_status} =
      System.shell("mix do deps.get, deps.nix --env prod 2>&1",
        cd: "fixtures/example"
      )

    assert run_status == 0, run_output

    assert {"«lambda @ " <> _, 0} =
             System.shell("nix eval --file deps.nix 2> /dev/null",
               cd: "fixtures/example"
             )

    {diff, diff_status} =
      System.shell("diff --unified deps.nix <(nixfmt < deps.nix)",
        cd: "fixtures/example"
      )

    assert diff_status == 0, diff
  end
end
