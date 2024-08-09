defmodule DepsNix.FetchGitTest do
  use ExUnit.Case, async: true

  alias DepsNix.FetchGit

  describe "string representation" do
    test "uses builtin fetcher to avoid prefetching" do
      assert %FetchGit{
               url: "https://github.com/sstoltze/tds",
               rev: "somehash"
             }
             |> to_string() ==
               """
               builtins.fetchGit {
                 url = "https://github.com/sstoltze/tds";
                 rev = "somehash";
                 allRefs = true;
               };\
               """
    end
  end
end
