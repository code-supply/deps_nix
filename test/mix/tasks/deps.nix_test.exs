defmodule Mix.Tasks.Deps.NixTest do
  use ExUnit.Case, async: true

  test "produces the expected Nix function for the fixture app" do
    {stdout, exit_status} =
      System.cmd("mix", ~w(deps.nix), cd: "fixtures/example", into: [], lines: 1024)

    expected =
      File.stream!("fixtures/example/deps.nix")
      |> Enum.map(&String.trim_trailing/1)

    assert exit_status == 0
    assert stdout == expected
  end
end
