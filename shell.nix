{ pkgs }:

with pkgs;

mkShell {
  packages =
    let
      release = writeShellApplication {
        name = "release";
        runtimeInputs = [ elixir_1_16 gh ];
        text = ''
          tag=$1

          gh release create "$tag" --draft --generate-notes
          mix hex.publish
        '';
      };
    in
    [
      beamPackages.hex
      elixir_1_16
      (elixir_ls.override { elixir = elixir_1_16; })
      gh
      release
    ];
}
