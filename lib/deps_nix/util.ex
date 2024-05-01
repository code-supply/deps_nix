defmodule DepsNix.Util do
  @spec indent(String.t() | nil) :: String.t()
  def indent(nil) do
    ""
  end

  def indent(str) do
    ("  " <> str)
    |> String.replace(~r/\n(.+)/, "\n  \\1")
    |> String.replace(~r/^ +$/, "")
  end

  def indent(str, from: start_line) do
    lines = String.split(str, "\n")
    not_indented = Enum.take(lines, start_line)
    indented = Enum.drop(lines, start_line)

    not_indented_result = not_indented |> Enum.join("\n")
    indent_result = indented |> Enum.map_join("\n", &indent/1)

    [not_indented_result, indent_result] |> Enum.join("\n")
  end
end
