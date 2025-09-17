defmodule DepsNix do
  alias DepsNix.Packages
  alias DepsNix.Util

  defmodule Options do
    @type t :: %Options{
            envs: map(),
            github_prefetcher: (String.t(), String.t(), String.t() -> String.t()),
            output: String.t(),
            app_config_path: String.t() | nil,
            include_paths: boolean(),
            cwd: String.t()
          }
    defstruct envs: %{},
              github_prefetcher: nil,
              output: "deps.nix",
              app_config_path: nil,
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
      strict: [env: [:string, :keep], output: :string, app_config_path: :string, include_paths: :boolean]
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
         nar = ExNar.serialize!(path),
         nar_hash = :crypto.hash(:sha256, nar),
         hash = "sha256-" <> Base.encode64(nar_hash) do
      {hash, find_builder_from_path(path)}
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

  defp find_builder_from_path(path) do
    cond do
      File.exists?(Path.join(path, "mix.exs")) -> "buildMix"
      File.exists?(Path.join(path, "rebar.config")) -> "buildRebar3"
      true -> :unknown
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
        include_paths: Keyword.get(opts, :include_paths, false),
        app_config_path: Keyword.get(opts, :app_config_path, nil)
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
    dep.app != :heroicons &&
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
        overrideFenixOverlay ? null,
      }:

      let
        buildMix = lib.makeOverridable beamPackages.buildMix;
        buildRebar3 = lib.makeOverridable beamPackages.buildRebar3;

        workarounds = {
          portCompiler = _unusedArgs: old: {
            buildPlugins = [ pkgs.beamPackages.pc ];
          };

          rustlerPrecompiled =
            {
              toolchain ? null,
              ...
            }:
            old:
            let
              extendedPkgs = pkgs.extend fenixOverlay;
              fenixOverlay =
                if overrideFenixOverlay == null then
                  import "${
                    fetchTarball {
                      url = "https://github.com/nix-community/fenix/archive/056c9393c821a4df356df6ce7f14c722dc8717ec.tar.gz";
                      sha256 = "sha256:1cdfh6nj81gjmn689snigidyq7w98gd8hkl5rvhly6xj7vyppmnd";
                    }
                  }/overlay.nix"
                else
                  overrideFenixOverlay;
              nativeDir = "${old.src}/native/${with builtins; head (attrNames (readDir "${old.src}/native"))}";
              fenix =
                if toolchain == null then
                  extendedPkgs.fenix.stable
                else
                  extendedPkgs.fenix.fromToolchainName toolchain;
              native =
                (extendedPkgs.makeRustPlatform {
                  inherit (fenix) cargo rustc;
                }).buildRustPackage
                  {
                    pname = "${old.packageName}-native";
                    version = old.version;
                    src = nativeDir;
                    cargoLock = {
                      lockFile = "${nativeDir}/Cargo.lock";
                    };
                    nativeBuildInputs = [
                      extendedPkgs.cmake
                    ];
                    doCheck = false;
                  };

            in
            {
              nativeBuildInputs = [ extendedPkgs.cargo ];

              env.RUSTLER_PRECOMPILED_FORCE_BUILD_ALL = "true";
              env.RUSTLER_PRECOMPILED_GLOBAL_CACHE_PATH = "unused-but-required";

              preConfigure = ''
                mkdir -p priv/native
                for lib in ${native}/lib/*
                do
                  ln -s "$lib" "priv/native/$(basename "$lib")"
                done
              '';

              buildPhase = ''
                suggestion() {
                  echo "***********************************************"
                  echo "                 deps_nix                      "
                  echo
                  echo " Rust dependency build failed.                 "
                  echo
                  echo " If you saw network errors, you might need     "
                  echo " to disable compilation on the appropriate     "
                  echo " RustlerPrecompiled module in your             "
                  echo " application config.                           "
                  echo
                  echo " We think you need this:                       "
                  echo
                  echo -n " "
                  grep -Rl 'use RustlerPrecompiled' lib \\
                    | xargs grep 'defmodule' \\
                    | sed 's/defmodule \\(.*\\) do/config :${old.packageName}, \\1, skip_compilation?: true/'
                  echo "***********************************************"
                  exit 1
                }
                trap suggestion ERR
                ${old.buildPhase}
              '';
            };
        };

        defaultOverrides = (
          final: prev:

          let
            apps = {
              crc32cer = [
                {
                  name = "portCompiler";
                }
              ];
              explorer = [
                {
                  name = "rustlerPrecompiled";
                  toolchain = {
                    name = "nightly-2024-11-01";
                    sha256 = "sha256-wq7bZ1/IlmmLkSa3GUJgK17dTWcKyf5A+ndS9yRwB88=";
                  };
                }
              ];
              snappyer = [
                {
                  name = "portCompiler";
                }
              ];
            };

            applyOverrides =
              appName: drv:
              let
                allOverridesForApp = builtins.foldl' (
                  acc: workaround: acc // (workarounds.${workaround.name} workaround) drv
                ) { } apps.${appName};

              in
              if builtins.hasAttr appName apps then drv.override allOverridesForApp else drv;

          in
          builtins.mapAttrs applyOverrides prev
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
