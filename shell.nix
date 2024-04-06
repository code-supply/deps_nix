{ pkgs }:

with pkgs;

mkShell {
  packages = [
    elixir_1_16
    (elixir_ls.override { elixir = elixir_1_16; })
  ];
}
