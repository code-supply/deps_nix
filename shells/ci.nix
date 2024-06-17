{ pkgs }:

with pkgs;

mkShell {
  packages =
    [
      beamPackages.hex
      elixir
      nixpkgs-fmt
    ];
}
