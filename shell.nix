{ pkgs }:

with pkgs;

mkShell {
  packages = [
    elixir_1_16
    (elixir_ls.override { elixir = elixir_1_16; })
    mix2nix # for comparison
  ];
}
