# WORKAROUND(2026-06-10): Run Orca Slicer through nix-alien because the normal
# package has missing runtime libraries and renders a blank prepare view.
# Disabled (2026-09-27) to re-test the normal package before removing the workaround.
{
  pkgs,
  inputs,
  config,
  lib,
  ...
}: let
  system = pkgs.stdenv.system;
in {
  home.packages = [
    pkgs.orca-slicer
    # inputs.nix-alien.packages.${system}.nix-alien
  ];
  # home.file.".local/share/applications/orca-slicer.desktop".text = ''
  #   [Desktop Entry]
  #   Name=Orca Slicer (nix-alien)
  #   Exec=sh -c 'nix-alien "$(which orca-slicer)"'
  #   Icon=orca-slicer
  #   Type=Application
  #   Terminal=false
  #   Categories=Graphics;
  # '';
}
