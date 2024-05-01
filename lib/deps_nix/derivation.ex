defmodule DepsNix.Derivation do
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
