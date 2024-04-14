defmodule Mix.Tasks.Deps.Nix do
  use Mix.Task

  @shortdoc "Produce nix derivations for mix dependencies"

  @impl Mix.Task
  def run(args) do
    Mix.Project.get!()

    {path, output} =
      (&Mix.Dep.Converger.converge/1)
      |> DepsNix.Run.call(DepsNix.Run.parse_args(args))

    File.write!(path, output)
  end
end
