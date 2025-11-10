{ pkgs }:

with pkgs;

mkShell {
  packages = [
    beamPackages.hex
    elixir_1_19
    nixfmt-rfc-style
  ];
}
