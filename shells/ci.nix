{ pkgs }:

with pkgs;

mkShell {
  packages =
    [
      beamPackages.hex
      elixir_1_16
      nixpkgs-fmt
    ];
}
