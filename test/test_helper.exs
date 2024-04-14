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

  def version_constraint() do
    version()
  end

  def dep(opts \\ []) do
    builders = Keyword.get(opts, :builders, DepsNix.builders())
    name = Keyword.get(opts, :name)
    version = Keyword.get(opts, :version)
    sub_deps = Keyword.get(opts, :sub_deps, [])

    gen all name <- if(name, do: constant(name), else: atom(:alphanumeric)),
            version <- if(version, do: constant(version), else: version()),
            hash1 <- string(:alphanumeric, length: 64),
            hash2 <- string(:alphanumeric, length: 64) do
      %Mix.Dep{
        app: name,
        requirement: version_constraint(),
        opts: [
          lock:
            {:hex, name, version, hash1, builders,
             Enum.map(sub_deps, fn dep -> {dep.app, dep.requirement, []} end), "hexpm", hash2},
          env: :prod
        ],
        deps: sub_deps
      }
    end
  end
end
