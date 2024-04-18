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
        choose_prefetcher(System.get_env("EMPTY_GIT_HASHES"))
      )

    File.write!(path, output)
  end

  defp choose_prefetcher(nil) do
    &prefetcher/2
  end

  defp choose_prefetcher(_) do
    fn _url, _rev -> "{}" end
  end

  defp prefetcher(url, rev) do
    {output, 0} = System.cmd("nix-prefetch-git", ["--quiet", url, rev])
    output
  rescue
    e in ErlangError ->
      Mix.shell().error(
        "Git dependency encountered: #{url}\nHave you installed nix-prefetch-scripts?"
      )

      reraise e, __STACKTRACE__
  end
end
