{ pkgs }:

with pkgs;

mkShell {
  packages =
    let
      release = writeShellApplication {
        name = "release";
        runtimeInputs = [
          elixir
          gh
        ];
        text = ''
          tag=$1

          gh release create "$tag" --draft --generate-notes
          mix hex.publish
        '';
      };
    in
    [
      elixir
      elixir_ls
      gh
      nixfmt-rfc-style
      release
    ];
}
