{ pkgs }:

with pkgs;

mkShell {
  packages =
    [
      beamPackages.hex
      elixir_1_16
      (elixir_ls.override { elixir = elixir_1_16; })
    ];
}
