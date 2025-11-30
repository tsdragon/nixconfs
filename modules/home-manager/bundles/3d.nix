{ config, pkgs, lib, ... }:

# Fixes issue with LycheeSlicer not being found by desktop entry
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
