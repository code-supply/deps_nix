defmodule Mix.Tasks.Deps.Nix do
  use Mix.Task

  @shortdoc "Produce nix derivations for mix dependencies"

  @impl Mix.Task
  def run(_args) do
    Mix.Project.get!()
    loaded_opts = [env: :prod, target: Mix.target()]

    shell = Mix.shell()

    (&Mix.Dep.Converger.converge/1)
    |> DepsNix.Run.call(loaded_opts)
    |> shell.info()
  end
end
