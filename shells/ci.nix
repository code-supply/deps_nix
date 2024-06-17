{ pkgs }:

with pkgs;

mkShell {
  packages =
    [
      beamPackages.hex
      elixir_1_17
      nixpkgs-fmt
    ];
}
