defmodule Mix.Tasks.Deps.NixTest do
  use ExUnit.Case, async: true

  test "produces a Nix function for the fixture app's dependencies" do
    assert {_, 0} =
             System.shell(~s/mix deps.nix --env prod/,
               cd: "fixtures/example",
               env: %{"EMPTY_GIT_HASHES" => "please"}
             )

    assert {"«lambda @ «string»:1:1»", 0} =
             System.shell(~s/nix eval --expr "$(cat deps.nix)"/,
               cd: "fixtures/example",
               into: "",
               lines: 1024
             )
  end
end
