ExUnit.start()

defmodule TestHelpers do
  use ExUnitProperties

  def builders do
    [:mix, :rebar3, :make]
  end

  def url do
    gen all scheme <- member_of(~w(http:// git://)),
            fragment <- one_of([nil, string(:alphanumeric)]),
            host <- string(:alphanumeric),
            tld <- string(:alphanumeric, max_length: 10),
            path_parts <- list_of(string(:alphanumeric)),
            path <- one_of([nil, constant("/" <> Enum.join(path_parts, "/"))]),
            port <- one_of([nil, integer(0..65535)]),
            query <- binary() do
      %URI{
        fragment: fragment,
        host: "#{host}.#{tld}",
        path: path,
        port: port,
        query: query,
        scheme: scheme
      }
      |> to_string()
    end
  end

  def hash do
    string(:alphanumeric)
  end

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
    builders = Keyword.get(opts, :builders, builders())
    name = Keyword.get(opts, :name)
    version = Keyword.get(opts, :version)
    sub_deps = Keyword.get(opts, :sub_deps, [])
    scm = Keyword.get(opts, :scm, Mix.SCM.Hex)

    gen all name <- if(name, do: constant(name), else: atom(:alphanumeric)),
            version <- if(version, do: constant(version), else: version()),
            hash1 <- string(:alphanumeric, length: 64),
            hash2 <- string(:alphanumeric, length: 64) do
      lock =
        Keyword.get(opts, :lock, {
          :hex,
          name,
          version,
          hash1,
          builders,
          Enum.map(sub_deps, fn dep -> {dep.app, dep.requirement, []} end),
          "hexpm",
          hash2
        })

      %Mix.Dep{
        app: name,
        scm: scm,
        requirement: version_constraint(),
        opts: [
          lock: lock,
          env: :prod
        ],
        deps: sub_deps
      }
    end
  end
end
