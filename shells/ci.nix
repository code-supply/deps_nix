{ pkgs }:

with pkgs;

mkShell {
  packages = [
    beamPackages.hex
    elixir
    nixfmt-rfc-style
  ];
}
