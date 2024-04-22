defmodule DepsNix do
  alias DepsNix.Derivation
  alias DepsNix.FetchGit
  alias DepsNix.FetchHex

  @apps_requiring_eponymous_dir [:grpcbox, :png]

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
      beam_deps: beam_deps(dep),
      unpack_phase: unpack_phase(dep.app, version)
    }
  end

  defp beam_deps(dep) do
    Enum.map(dep.deps, & &1.app)
  end

  defp unpack_phase(name, version) when name in @apps_requiring_eponymous_dir do
    """
    runHook preUnpack
    unpackFile "$src"
    chmod -R u+w -- hex-source-#{name}-#{version}
    mv hex-source-#{name}-#{version} #{name}
    sourceRoot=#{name}
    runHook postUnpack
    """
  end

  defp unpack_phase(_name, _version) do
  end

  defp nix_builder(builders) do
    cond do
      Enum.member?(builders, :mix) -> "buildMix"
      Enum.member?(builders, :rebar3) -> "buildRebar3"
    end
  end
end
