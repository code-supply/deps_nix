defmodule DepsNix.Derivation do
  alias DepsNix.Util

  @type t :: %__MODULE__{
          builder: String.t(),
          name: atom(),
          version: String.t(),
          src: DepsNix.FetchHex.t(),
          beam_deps: list(atom()),
          unpack_phase: String.t() | nil
        }

  @enforce_keys [:builder, :name, :version, :src, :beam_deps]
  defstruct [:builder, :name, :version, :src, :beam_deps, :unpack_phase]

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

          src = #{indented_src(drv.src)};

          beamDeps = #{format_beam_deps(drv.beam_deps)};#{unpack_phase(drv.unpack_phase)}
        };
      """
    end

    defp indented_src(src) do
      src
      |> Kernel.to_string()
      |> Util.indent(from: 1)
      |> Util.indent(from: 1)
    end

    defp unpack_phase(nil) do
    end

    defp unpack_phase(script) do
      """


      unpackPhase = ''
      #{script |> String.trim_trailing() |> Util.indent()}
      '';\
      """
      |> Util.indent(from: 2)
      |> Util.indent(from: 2)
    end

    defp format_beam_deps([]) do
      "[ ]"
    end

    defp format_beam_deps(deps) do
      "[ #{Enum.join(deps, " ")} ]"
    end
  end
end
