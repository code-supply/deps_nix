{ pkgs }:

with pkgs;

mkShell {
  packages =
    let
      release = writeShellApplication {
        name = "release";
        runtimeInputs = [
          elixir_1_19
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
      elixir_1_19
      elixir-ls
      gh
      nixfmt-rfc-style
      release
    ];
}
