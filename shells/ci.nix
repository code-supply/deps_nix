{
  beamPackages,
  pkgs,
}:

pkgs.mkShell {
  packages = [
    beamPackages.elixir
    beamPackages.hex
    pkgs.nixfmt
  ];
}
