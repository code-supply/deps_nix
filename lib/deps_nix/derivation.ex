defmodule DepsNix.Derivation do
  alias DepsNix.FetchGit
  alias DepsNix.FetchHex
  alias DepsNix.Util

  @type t :: %__MODULE__{
          builder: String.t(),
          name: atom(),
          version: String.t(),
          src: DepsNix.FetchHex.t(),
          beam_deps: list(atom())
        }

  @enforce_keys [:builder, :name, :version, :src, :beam_deps]
  defstruct [:builder, :name, :version, :src, :beam_deps]

  def new(dep, version, src, builder) do
    %__MODULE__{
      name: dep.app,
      version: version,
      builder: builder,
      src: src,
      beam_deps: Enum.map(dep.deps, & &1.app)
    }
  end

  @spec from(Mix.Dep.t()) :: t()
  def from(%Mix.Dep{scm: Mix.SCM.Git} = dep) do
    {:git, url, rev, _} = dep.opts[:lock]
    fetcher = %FetchGit{url: url, rev: rev}
    new(dep, rev, fetcher, "buildMix")
  end

  def from(%Mix.Dep{} = dep) do
    {:hex, name, version, _hash, beam_builders, _sub_deps, _, sha256} = dep.opts[:lock]
    fetcher = %FetchHex{pkg: name, version: version, sha256: sha256}
    new(dep, version, fetcher, nix_builder(beam_builders))
  end

  defp nix_builder(builders) do
    cond do
      Enum.member?(builders, :mix) -> "buildMix"
      Enum.member?(builders, :rebar3) -> "buildRebar3"
    end
  end

  defimpl String.Chars do
    def to_string(drv) do
      """
      #{drv.name} =
        let
          version = "#{drv.version}";
        in
        #{drv.builder} {
          inherit version;
          name = "#{drv.name}";

          src = #{src(drv.src)}#{beam_deps(drv.beam_deps)}
        };
      """
    end

    defp src(src) do
      src
      |> Kernel.to_string()
      |> Util.indent(from: 1)
      |> Util.indent(from: 1)
    end

    defp beam_deps([]) do
      ""
    end

    defp beam_deps(deps) do
      """


      beamDeps = [ #{Enum.join(deps, " ")} ];\
      """
      |> Util.indent(from: 2)
      |> Util.indent(from: 2)
    end
  end
end
