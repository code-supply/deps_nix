{ beamPackages, pkgs }:

pkgs.mkShell {
  packages =
    let
      release = pkgs.writeShellApplication {
        name = "release";
        runtimeInputs = [
          beamPackages.elixir
          beamPackages.hex
          pkgs.gh
        ];
        text = ''
          tag="v$(tr -d '[:space:]' < VERSION)"

          gh release create "$tag" --draft --generate-notes
          mix hex.publish
        '';
      };
    in
    [
      beamPackages.elixir
      beamPackages.elixir-ls
      beamPackages.hex
      pkgs.gh
      pkgs.nixfmt
      release
    ];
}
