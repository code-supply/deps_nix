defmodule DepsNix.FetchFromGitHubTest do
  use ExUnit.Case, async: true

  alias DepsNix.FetchFromGitHub

  describe "string representation" do
    test "uses fetcher" do
      assert %FetchFromGitHub{
               owner: "sstoltze",
               repo: "tds",
               rev: "somegithash",
               hash: "someunpackedhash"
             }
             |> to_string() ==
               """
               pkgs.fetchFromGitHub {
                 owner = "sstoltze";
                 repo = "tds";
                 rev = "somegithash";
                 hash = "someunpackedhash";
               };\
               """
    end
  end
end
