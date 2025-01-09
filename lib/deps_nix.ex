defmodule DepsNix do
  alias DepsNix.Packages
  alias DepsNix.Util

  defmodule Options do
    @type t :: %Options{
            envs: map(),
            github_prefetcher: (String.t(), String.t(), String.t() -> String.t()),
            output: String.t(),
            include_paths: boolean(),
            cwd: String.t()
          }
    defstruct envs: %{},
              github_prefetcher: nil,
              output: "deps.nix",
              include_paths: false,
              cwd: nil
  end

  defmodule InvalidGitHubReference do
    defexception [:message]
  end

  @type converger :: (Keyword.t() -> list(Mix.Dep.t()))

  @spec run(Options.t(), converger()) ::
          {path :: String.t(), output :: String.t()}
  def run(opts, converger) do
    opts
    |> convert_opts()
    |> Enum.flat_map(fn {converger_opts, permitted_names} ->
      all_packages_for_env = converger.(converger_opts)

      Packages.filter(all_packages_for_env, permitted_names)
      |> then(fn packages ->
        if opts.include_paths do
          packages
        else
          Packages.reject_paths(packages)
        end
      end)
    end)
    |> Enum.reject(&unwanted/1)
    |> Enum.sort_by(& &1.app)
    |> Enum.uniq()
    |> Enum.map(&DepsNix.Derivation.from(&1, opts))
    |> Enum.join("\n")
    |> indent_deps()
    |> wrap(opts.output)
  end

  @spec parse_args(list()) :: Options.t()
  def parse_args(args) do
    args
    |> OptionParser.parse(
      strict: [env: [:string, :keep], output: :string, include_paths: :boolean]
    )
    |> to_opts()
  end

  def github_prefetcher(owner, repo, rev) do
    Mix.shell().info("deps_nix: fetching hash for GitHub dependency #{owner}/#{repo}")

    with dir <- System.tmp_dir() |> realpath(),
         path <- "#{dir}/#{repo}-#{rev}",
         {:ok, _deletions} <- File.rm_rf(path),
         body <- github_archive(owner, repo, rev),
         :ok <- File.write("#{dir}/deps-nix-tarball", body),
         {_, 0} <- System.cmd("tar", ["-xf", "#{dir}/deps-nix-tarball"], cd: dir),
         {output, 0} <- System.cmd("nix", ["hash", "path", path]) do
      String.trim_trailing(output)
    end
  end

  defp realpath(path) do
    for subpath <- Path.split(path), reduce: "/" do
      acc ->
        new_path = Path.join(acc, subpath)

        case File.read_link(new_path) do
          {:ok, resolved} -> Path.join("/", resolved)
          {:error, _} -> new_path
        end
    end
  end

  defp github_archive(owner, repo, rev) do
    {:ok, conn} = Mint.HTTP.connect(:https, "codeload.github.com", 443)

    {:ok, conn, request_ref} =
      Mint.HTTP.request(conn, "GET", "/#{owner}/#{repo}/tar.gz/#{rev}", [], "")

    receive_archive(conn, request_ref)
  end

  defp receive_archive(conn, request_ref, data \\ []) do
    receive do
      message ->
        case Mint.HTTP.stream(conn, message) do
          {:ok, conn, responses} ->
            case Enum.reduce(responses, data, fn
                   {:status, ^request_ref, 200}, acc ->
                     acc

                   {:status, ^request_ref, 404}, _acc ->
                     raise InvalidGitHubReference

                   {:headers, ^request_ref, _headers}, acc ->
                     acc

                   {:data, ^request_ref, data}, acc ->
                     [data | acc]

                   {:done, ^request_ref}, acc ->
                     {:ok, acc}
                 end) do
              {:ok, data} ->
                Enum.reverse(data)

              data ->
                receive_archive(conn, request_ref, data)
            end
        end
    end
  end

  @spec to_opts({list(), any(), any()}) :: Options.t()
  defp to_opts({[], _, _}) do
    %Options{
      cwd: File.cwd!(),
      envs: %{"prod" => :all},
      github_prefetcher: &github_prefetcher/3
    }
  end

  defp to_opts({opts, _, _}) do
    default = to_opts({[], [], []})

    %Options{
      default
      | envs:
          for {:env, env} <- opts, into: default.envs do
            case String.split(env, "=", parts: 2) do
              [env] ->
                {env, :all}

              [env, ""] ->
                {env, []}

              [env, packages] ->
                {env, String.split(packages, ",")}
            end
          end,
        include_paths: Keyword.get(opts, :include_paths, false)
    }
    |> add_output(opts)
  end

  defp convert_opts(%Options{envs: envs}) do
    for {strenv, packages} <- envs do
      env = String.to_existing_atom(strenv)
      {[env: env], packages}
    end
  end

  defp unwanted(dep) do
    Enum.all?([:app, :compile], fn opt ->
      Keyword.fetch(dep.opts, opt) == {:ok, false}
    end)
  end

  defp add_output(options, parsed_args) do
    case Keyword.get(parsed_args, :output) do
      nil ->
        options

      output ->
        %Options{options | output: output}
    end
  end

  defp wrap(pkgs, output) do
    {
      output,
      """
      {
        pkgs,
        lib,
        beamPackages,
        overrides ? (x: y: { }),
      }:

      let
        buildMix = lib.makeOverridable beamPackages.buildMix;
        buildRebar3 = lib.makeOverridable beamPackages.buildRebar3;

        defaultOverrides = (
      #{default_overrides()}
        );

        self = packages // (defaultOverrides self packages) // (overrides self packages);

        packages =
          with beamPackages;
          with self;
          {
      #{pkgs}
          };
      in
      self
      """
    }
  end

  defp default_overrides do
    "#{:code.priv_dir(:deps_nix)}/default-overrides.nix"
    |> File.read!()
    |> String.trim_trailing()
    |> Util.indent()
    |> Util.indent()
  end

  defp indent_deps("") do
    " "
  end

  defp indent_deps(s) do
    "\n#{s}"
    |> Util.indent(from: 1)
    |> Util.indent(from: 1)
    |> Util.indent(from: 1)
  end
end
