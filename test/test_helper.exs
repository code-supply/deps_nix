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
    sub_deps = Keyword.get(opts, :sub_deps)

    gen all name <- if(name, do: constant(name), else: atom(:alphanumeric)),
            version <- if(version, do: constant(version), else: version()),
            hash1 <- string(:alphanumeric, length: 64),
            hash2 <- string(:alphanumeric, length: 64),
            sub_deps <-
              if(sub_deps,
                do: constant(deps_to_sub_deps(sub_deps)),
                else: list_of({atom(:alphanumeric), version_constraint(), constant([])})
              ) do
      %Mix.Dep{
        app: name,
        requirement: version_constraint(),
        opts: [
          lock: {:hex, name, version, hash1, builders, sub_deps, "hexpm", hash2},
          env: :prod
        ]
      }
    end
  end

  defp deps_to_sub_deps(deps) do
    Enum.map(deps, fn dep ->
      {dep.app, dep.requirement, []}
    end)
  end
end
