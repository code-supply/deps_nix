defmodule DepsNix.Path do
  @type t :: %__MODULE__{
          path: String.t()
        }

  @enforce_keys [:path]
  defstruct [:path]

  defimpl String.Chars do
    def to_string(path) do
      "#{path.path};"
    end
  end
end
