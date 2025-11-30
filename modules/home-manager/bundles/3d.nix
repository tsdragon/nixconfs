{ config, pkgs, lib, ... }:

let
  lycheeWrapper = pkgs.writeShellScriptBin "lychee" ''
    exec LycheeSlicer "$@"
  '';
in
{
  imports = [
    ../apps/orca-slicer.nix
  ];

  home.packages = with pkgs; [
    blender
    openscad
    unityhub
    LycheeSlicer
    lycheeWrapper
  ];
}
