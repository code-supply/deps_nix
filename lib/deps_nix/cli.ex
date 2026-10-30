defmodule DepsNix.CLI do
  def main(args) do
    case DepsNix.parse_args(args) do
      :help ->
        IO.ANSI.Docs.print_headings(["deps_nix"])
        IO.ANSI.Docs.print(DepsNix.Docs.markdown("deps_nix"), "text/markdown", [])

      :version ->
        IO.puts("deps_nix #{DepsNix.version()}")

      opts ->
        generate(opts)
    end
  end

  defp generate(opts) do
    {:ok, _started_apps} = Application.ensure_all_started([:mint, :mix])

    Code.compile_file(Path.absname(System.get_env("MIX_EXS", "mix.exs")))

    Mix.Project.get!()

    {path, output} = DepsNix.run(opts, &converge/1)

    File.write!(path, output)
  end

  defp converge(opts) do
    deps = Mix.Dep.Converger.converge(opts)

    case Enum.filter(deps, &match?(%Mix.Dep{status: {:unavailable, _}}, &1)) do
      [] ->
        deps

      missing ->
        names = Enum.map_join(missing, ", ", & &1.app)

        Mix.raise(
          "Cannot generate Nix dependencies: dependency sources are missing: #{names}. " <>
            "Run `mix deps.get`, then retry."
        )
    end
  end
end
