{
  beamPackages,
  pkgs,
}:

pkgs.mkShell {
  packages = [
    beamPackages.hex
    beamPackages.elixir
    pkgs.nixfmt-rfc-style
  ];
}
