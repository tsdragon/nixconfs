{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    exactaudiocopy
    lame
  ];
}
