defmodule DepsNix do
  alias DepsNix.Derivation
  alias DepsNix.FetchGit
  alias DepsNix.FetchHex

  @spec transform(Mix.Dep.t()) :: Derivation.t()
  def transform(%Mix.Dep{scm: Mix.SCM.Git} = dep) do
    {:git, url, rev, _} = dep.opts[:lock]
    fetcher = %FetchGit{url: url, rev: rev}
    derivation(dep, rev, fetcher, "buildMix")
  end

  def transform(%Mix.Dep{} = dep) do
    {:hex, name, version, _hash, beam_builders, _sub_deps, _, sha256} = dep.opts[:lock]
    fetcher = %FetchHex{pkg: name, version: version, sha256: sha256}
    derivation(dep, version, fetcher, nix_builder(beam_builders))
  end

  defp derivation(dep, version, src, builder) do
    %Derivation{
      name: dep.app,
      version: version,
      builder: builder,
      src: src,
      beam_deps: beam_deps(dep)
    }
  end

  defp beam_deps(dep) do
    Enum.map(dep.deps, & &1.app)
  end

  defp nix_builder(builders) do
    cond do
      Enum.member?(builders, :mix) -> "buildMix"
      Enum.member?(builders, :rebar3) -> "buildRebar3"
    end
  end
end
