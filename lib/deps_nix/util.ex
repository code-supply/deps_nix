defmodule DepsNix.Util do
  @spec indent(String.t() | nil) :: String.t()
  def indent(nil) do
    ""
  end

  def indent(str) do
    ("  " <> str)
    |> String.replace(~r/\n(.+)/, "\n  \\1")
  end

  def indent(str, from: start_line) do
    lines = String.split(str, "\n")
    no_indent = Enum.take(lines, start_line)
    indent = Enum.drop(lines, start_line)

    no_indent_result = no_indent |> Enum.join("\n")
    indent_result = indent |> Enum.join("\n") |> indent()

    [no_indent_result, indent_result] |> Enum.join("\n")
  end
end
