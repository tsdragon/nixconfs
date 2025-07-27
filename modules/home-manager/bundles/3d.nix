{ config, pkgs, lib, ... }:

{
  imports = [
    ../apps/orca-slicer.nix
  ];

  home.packages = with pkgs; [
    blender
    openscad
    unityhub
  ];
}
