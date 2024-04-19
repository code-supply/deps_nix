defmodule DepsNix do
  alias DepsNix.Derivation
  alias DepsNix.FetchGit
  alias DepsNix.FetchHex

  @apps_requiring_eponymous_dir [:grpcbox, :png]

  @spec transform(
          Mix.Dep.t(),
          fetcher :: (url :: String.t(), rev :: String.t() -> String.t())
        ) :: Derivation.t()
  def transform(%Mix.Dep{scm: Mix.SCM.Git} = dep, prefetcher) do
    {:git, url, rev, _} = dep.opts[:lock]
    json = prefetcher.(url, rev)
    prefetch_result = Jason.decode!(json)
    fetcher = %FetchGit{url: url, rev: rev, hash: prefetch_result["hash"]}
    derivation(dep, rev, fetcher, "buildMix")
  end

  def transform(%Mix.Dep{} = dep, _prefetcher) do
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
