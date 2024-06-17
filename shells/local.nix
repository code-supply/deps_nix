{ pkgs }:

with pkgs;

mkShell {
  packages =
    let
      elixir = elixir_1_17;
      release = writeShellApplication {
        name = "release";
        runtimeInputs = [ elixir gh ];
        text = ''
          tag=$1

          gh release create "$tag" --draft --generate-notes
          mix hex.publish
        '';
      };
    in
    [
      beamPackages.hex
      elixir
      (elixir_ls.override { inherit elixir; })
      gh
      nixpkgs-fmt
      release
    ];
}
