defmodule DepsNix.CLITest do
  use ExUnit.Case, async: true

  setup do
    root = File.cwd!()
    project = Path.join(System.tmp_dir!(), "deps-nix-cli-#{System.unique_integer([:positive])}")
    File.mkdir_p!(project)

    for file <- ["mix.exs", "mix.lock", "VERSION"] do
      File.cp!(Path.join(root, file), Path.join(project, file))
    end

    code_paths =
      Mix.Project.build_path()
      |> Path.join("lib/*/ebin")
      |> Path.wildcard()
      |> Enum.flat_map(&["-pa", &1])

    on_exit(fn -> File.rm_rf!(project) end)
    %{root: root, project: project, code_paths: code_paths}
  end

  test "rejects missing sources without overwriting output", context do
    output = Path.join(context.project, "deps.nix")
    File.write!(output, "existing output")

    {message, status} = run_cli(context)

    assert status != 0
    assert message =~ "dependency sources are missing"
    assert message =~ "mint"
    assert message =~ "mix deps.get"
    assert File.read!(output) == "existing output"
    refute File.exists?(Path.join(context.project, "_build"))
    refute File.exists?(Path.join(context.project, "deps"))
  end

  test "rejects missing transitive sources in a partially fetched project", context do
    add_sources(context, ["mint", "ex_nar"])

    {message, status} = run_cli(context)

    assert status != 0
    assert message =~ "dependency sources are missing: hpax"
    assert message =~ "mix deps.get"
    refute File.exists?(Path.join(context.project, "deps.nix"))
    refute File.exists?(Path.join(context.project, "_build"))
  end

  test "preserves transitive dependencies without compiling fetched sources", context do
    add_sources(context, ["mint", "ex_nar", "hpax"])

    {message, status} = run_cli(context)

    assert status == 0, message
    output = File.read!(Path.join(context.project, "deps.nix"))
    assert output =~ "hpax ="
    assert output =~ ~r/beamDeps = \[\s+hpax\s+\];/
    refute File.exists?(Path.join(context.project, "_build"))
  end

  defp add_sources(context, names) do
    File.mkdir_p!(Path.join(context.project, "deps"))

    for name <- names do
      File.ln_s!(
        Path.join([context.root, "deps", name]),
        Path.join([context.project, "deps", name])
      )
    end
  end

  defp run_cli(context) do
    System.cmd(
      "elixir",
      context.code_paths ++
        ["-e", "DepsNix.CLI.main(System.argv())", "--", "--no-app-config"],
      cd: context.project,
      stderr_to_stdout: true
    )
  end
end
