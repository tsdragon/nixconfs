# 20251130 - Wrap Orca Slicer with nix-alien to fix missing library issues.
# without it the prep viewer will be blank.
{ pkgs, inputs, config, lib, ... }:
let
  system = pkgs.stdenv.system;
in {
  home.packages = [
    pkgs.orca-slicer
    inputs.nix-alien.packages.${system}.nix-alien
  ];
  home.file.".local/share/applications/orca-slicer.desktop".text = ''
    [Desktop Entry]
    Name=Orca Slicer (nix-alien)
    Exec=sh -c 'nix-alien "$(which orca-slicer)"'
    Icon=orca-slicer
    Type=Application
    Terminal=false
    Categories=Graphics;
  '';
}