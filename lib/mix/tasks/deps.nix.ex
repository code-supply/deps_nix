defmodule Mix.Tasks.Deps.Nix do
  use Mix.Task

  @shortdoc "Produce nix derivations for mix dependencies"

  @impl Mix.Task
  def run(args) do
    Mix.Project.get!()

    {path, output} =
      DepsNix.Run.call(
        DepsNix.Run.parse_args(args),
        &Mix.Dep.Converger.converge/1,
        fn _url, _rev ->
          "{}"
        end
      )

    File.write!(path, output)
  end
end
