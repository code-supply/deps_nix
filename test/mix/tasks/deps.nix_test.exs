defmodule Mix.Tasks.Deps.NixTest do
  use ExUnit.Case, async: true

  test "produces a Nix function for the fixture app's dependencies" do
    assert {_, 0} =
             System.shell("mix deps.nix --env prod",
               cd: "fixtures/example",
               env: %{"EMPTY_GIT_HASHES" => "please"}
             )

    assert {"«lambda @ " <> _, 0} =
             System.shell("nix eval --file deps.nix 2> /dev/null",
               cd: "fixtures/example",
               into: "",
               lines: 1024
             )
  end
end
