ExUnit.start()

defmodule TestHelpers do
  use ExUnitProperties

  def version do
    gen all major <- non_negative_integer(),
            minor <- non_negative_integer(),
            patch <- non_negative_integer() do
      "#{major}.#{minor}.#{patch}"
    end
  end

  def dep(opts \\ []) do
    builders = Keyword.get(opts, :builders, DepsNix.builders())
    name = Keyword.get(opts, :name)
    version = Keyword.get(opts, :version)

    gen all name <- if(name, do: constant(name), else: atom(:alphanumeric)),
            version <- if(version, do: constant(version), else: version()),
            hash1 <- string(:alphanumeric, length: 64),
            hash2 <- string(:alphanumeric, length: 64) do
      %Mix.Dep{
        app: name,
        opts: [
          lock: {:hex, name, version, hash1, builders, [], "hexpm", hash2},
          env: :prod
        ]
      }
    end
  end
end
