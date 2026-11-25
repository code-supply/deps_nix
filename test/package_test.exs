defmodule DepsNix.PackageTest do
  use ExUnit.Case, async: true

  test "Hex package includes the version file required to load its project" do
    package =
      Path.join(System.tmp_dir!(), "deps-nix-package-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf!(package) end)

    {output, status} =
      System.cmd("mix", ["hex.build", "--unpack", "--output", package], stderr_to_stdout: true)

    assert status == 0, output
    assert File.read!(Path.join(package, "VERSION")) == File.read!("VERSION")

    for file <- ["mix.exs", ".formatter.exs", "README.md", "LICENSE", "lib/deps_nix.ex"] do
      assert File.exists?(Path.join(package, file))
    end

    {version, status} =
      System.cmd(
        "elixir",
        [
          "-e",
          "Mix.start(); Code.compile_file(\"mix.exs\"); IO.puts(Mix.Project.config()[:version])"
        ],
        cd: package,
        stderr_to_stdout: true
      )

    assert status == 0, version
    assert String.trim(version) == DepsNix.version()
  end
end
