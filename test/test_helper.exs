Mix.shell(Mix.Shell.Quiet)
ExUnit.start()

defmodule TestHelpers do
  use ExUnitProperties

  def builders do
    [:mix, :rebar3, :make]
  end

  def url(opts \\ []) do
    gen all scheme <- member_of(~w(http git)),
            fragment <- one_of([nil, string(:alphanumeric)]),
            host <-
              overridable(opts, :host, one_of([string(:alphanumeric), constant("github.com")])),
            tld <- overridable(opts, :tld, string(:alphanumeric, max_length: 10)),
            path_parts <- list_of(string(:alphanumeric)),
            path <-
              overridable(opts, :path, one_of([nil, constant("/" <> Enum.join(path_parts, "/"))])),
            port <- one_of([nil, integer(0..65535)]),
            query <- string(:alphanumeric) do
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

  def scm do
    one_of([Mix.SCM.Hex, Mix.SCM.Git])
  end

  def dep(opts \\ []) do
    builders = Keyword.get(opts, :builders, builders())
    name = Keyword.get(opts, :name)
    version = Keyword.get(opts, :version)
    sub_deps = Keyword.get(opts, :sub_deps, [])
    scm = Keyword.get(opts, :scm)
    dep_opts = Keyword.get(opts, :dep_opts, [])

    gen all name <- if(name, do: constant(name), else: atom(:alphanumeric)),
            version <- if(version, do: constant(version), else: version()),
            scm <- if(scm, do: constant(scm), else: scm()),
            url <- url(),
            hash1 <- string(:alphanumeric, length: 64),
            hash2 <- string(:alphanumeric, length: 64) do
      lock =
        case scm do
          Mix.SCM.Hex ->
            {
              :hex,
              name,
              version,
              hash1,
              builders,
              Enum.map(sub_deps, fn dep -> {dep.app, dep.requirement, []} end),
              "hexpm",
              hash2
            }

          Mix.SCM.Git ->
            {
              :git,
              Keyword.get(opts, :git_url, url),
              version,
              []
            }

          Mix.SCM.Path ->
            nil
        end

      %Mix.Dep{
        app: name,
        scm: scm,
        requirement: version,
        opts:
          [
            lock: lock,
            env: :prod
          ]
          |> Keyword.merge(dep_opts),
        deps: sub_deps
      }
    end
  end

  defp overridable(opts, key, default) do
    case Keyword.fetch(opts, key) do
      {:ok, val} -> constant(val)
      :error -> default
    end
  end
end
