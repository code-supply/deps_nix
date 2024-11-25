defmodule DepsNix.FetchFromGitHub do
  @type t :: %__MODULE__{
          owner: String.t(),
          repo: String.t(),
          rev: String.t(),
          hash: String.t()
        }

  @enforce_keys [
    :owner,
    :repo,
    :rev,
    :hash
  ]
  defstruct [
    :owner,
    :repo,
    :rev,
    :hash
  ]

  defimpl String.Chars do
    def to_string(%DepsNix.FetchFromGitHub{} = g) do
      """
      pkgs.fetchFromGitHub {
        owner = "#{g.owner}";
        repo = "#{g.repo}";
        rev = "#{g.rev}";
        hash = "#{g.hash}";
      };\
      """
    end
  end
end
