defmodule DepsNix.Derivation do
  alias DepsNix.FetchFromGitHub
  alias DepsNix.FetchGit
  alias DepsNix.FetchHex
  alias DepsNix.Util

  @type t :: %__MODULE__{
          app_config_path: String.t(),
          builder: String.t(),
          name: atom(),
          version: String.t(),
          src:
            DepsNix.FetchFromGitHub.t()
            | DepsNix.FetchGit.t()
            | DepsNix.FetchHex.t(),
          beam_deps: list(atom())
        }

  @enforce_keys [
    :app_config_path,
    :builder,
    :name,
    :version,
    :src,
    :beam_deps
  ]
  defstruct [
    :app_config_path,
    :builder,
    :name,
    :version,
    :src,
    :beam_deps
  ]

  def new(dep, opts) do
    struct!(
      __MODULE__,
      [
        name: dep.app,
        beam_deps: Enum.map(dep.deps, & &1.app)
      ]
      |> Keyword.merge(opts)
    )
  end

  @spec from(Mix.Dep.t(), DepsNix.Options.t()) :: t()
  def from(%Mix.Dep{scm: Mix.SCM.Git} = dep, options) do
    {:git, url, rev, _} = dep.opts[:lock]

    case parse_git_url(url) do
      [owner: owner, repo: repo] ->
        prefetcher = options.github_prefetcher

        {hash, builder} =
          if prefetcher do
            prefetcher.(owner, repo, rev)
          else
            {"", "buildMix"}
          end

        fetcher = %FetchFromGitHub{
          owner: owner,
          repo: repo,
          rev: rev,
          hash: hash
        }

        new(dep,
          version: rev,
          src: fetcher,
          builder: builder,
          app_config_path: app_config_path(options)
        )

      url ->
        fetcher = %FetchGit{url: url, rev: rev}

        new(dep,
          version: rev,
          src: fetcher,
          builder: "buildMix",
          app_config_path: app_config_path(options)
        )
    end
  end

  def from(%Mix.Dep{scm: Mix.SCM.Path} = dep, options) do
    new(
      dep,
      version: get_in(dep.opts, [:app_properties, :vsn]),
      src: %DepsNix.Path{
        path:
          Elixir.Path.relative_to(
            dep.opts[:dest],
            Elixir.Path.join(options.cwd, Elixir.Path.dirname(options.output)),
            force: true
          )
      },
      builder: nix_builder([:mix]),
      app_config_path: app_config_path(options)
    )
  end

  def from(%Mix.Dep{} = dep, options) do
    {:hex, name, version, _hash, beam_builders, _sub_deps, _, sha256} = dep.opts[:lock]
    fetcher = %FetchHex{pkg: name, version: version, sha256: sha256}

    new(dep,
      version: version,
      src: fetcher,
      builder: nix_builder(beam_builders),
      app_config_path: app_config_path(options)
    )
  end

  defp nix_builder(builders) do
    cond do
      Enum.member?(builders, :mix) -> "buildMix"
      Enum.member?(builders, :rebar3) -> "buildRebar3"
    end
  end

  @spec parse_git_url(String.t()) :: [owner: String.t(), repo: String.t()] | String.t()
  defp parse_git_url(url) do
    with path <- URI.parse(url).path,
         true <- path && String.contains?(url, "github.com"),
         [owner, repo | _] <- String.split(path, "/", trim: true),
         repo <- String.replace_suffix(repo, ".git", "") do
      [owner: owner, repo: repo]
    else
      _ -> url
    end
  end

  defp app_config_path(opts) do
    opts.output
    |> String.split("/")
    |> Enum.drop(1)
    |> Enum.reduce("config", fn _path_part, acc -> ["../", acc] end)
    |> IO.iodata_to_binary()
  end

  defimpl String.Chars do
    def to_string(%DepsNix.Derivation{name: :vix} = drv) do
      """
      vix =
        let
          version = "#{drv.version}";
          drv = #{drv.builder} {
            inherit version;
            name = "#{drv.name}";#{format_app_config_path(drv)}

            VIX_COMPILATION_MODE = "PLATFORM_PROVIDED_LIBVIPS";

            nativeBuildInputs = with pkgs; [
              pkg-config
              vips
            ];

            src = #{src(drv.src)}#{beam_deps(drv.beam_deps)}
          };
        in
        drv#{override(drv)};
      """
    end

    def to_string(%DepsNix.Derivation{name: :heroicons} = drv) do
      """
      #{drv.name} = #{drv.src |> Kernel.to_string()}
      """
    end

    def to_string(drv) do
      """
      #{drv.name} =
        let
          version = "#{drv.version}";
          drv = #{drv.builder} {
            inherit version;
            name = "#{drv.name}";#{format_app_config_path(drv)}

            src = #{src(drv.src)}#{beam_deps(drv.beam_deps)}#{post_unpack(drv)}
          };
        in
        drv#{override(drv)};
      """
    end

    defp post_unpack(%DepsNix.Derivation{name: :unicode_string}) do
      """


      postUnpack = ''
        data_dir="$(elixir -e "IO.puts Unicode.data_dir()")"
        unicode_dir="$(dirname "$data_dir")"
        tmp_dir="$(dirname "$unicode_dir")"
        ls -la /nix/var/nix
        mkdir -p "$tmp_dir"
        ln -sfv ${unicode.src} "$tmp_dir/${unicode.name}"
      '';\
      """
      |> Util.indent(from: 2)
      |> Util.indent(from: 2)
      |> Util.indent(from: 2)
    end

    defp post_unpack(_drv) do
      ""
    end

    defp src(src) do
      src
      |> Kernel.to_string()
      |> Util.indent(from: 1)
      |> Util.indent(from: 1)
      |> Util.indent(from: 1)
    end

    defp beam_deps([]) do
      ""
    end

    defp beam_deps(deps) do
      """


      beamDeps = [
        #{Enum.join(deps, "\n  ")}
      ];\
      """
      |> Util.indent(from: 2)
      |> Util.indent(from: 2)
      |> Util.indent(from: 2)
    end

    defp override(drv) do
      if :rustler_precompiled in drv.beam_deps do
        ".override (workarounds.rustlerPrecompiled { } drv)"
      else
        ""
      end
    end

    defp format_app_config_path(%DepsNix.Derivation{
           builder: "buildMix",
           app_config_path: path
         }) do
      "\nappConfigPath = #{prefix_path(path)};"
      |> Util.indent(from: 1)
      |> Util.indent(from: 1)
      |> Util.indent(from: 1)
    end

    defp format_app_config_path(_drv) do
      ""
    end

    defp prefix_path(<<".", _rest::binary>> = path) do
      path
    end

    defp prefix_path(path) do
      "./#{path}"
    end
  end
end
