defmodule Mix.Tasks.Deps.Nix do
  @moduledoc DepsNix.Docs.markdown("mix deps.nix")

  @shortdoc "Produce nix derivations for mix dependencies"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    case DepsNix.parse_args(args) do
      :help ->
        Mix.Task.run("help", ["deps.nix"])

      :version ->
        Mix.shell().info("deps_nix #{DepsNix.version()}")

      opts ->
        generate(opts)
    end
  end

  defp generate(opts) do
    {:ok, _started_apps} = Application.ensure_all_started(:mint)

    Mix.Project.get!()

    {path, output} = DepsNix.run(opts, &Mix.Dep.Converger.converge/1)

    File.write!(path, output)
  end
end
