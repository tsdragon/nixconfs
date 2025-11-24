{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    exactaudiocopy
    flac
    lame
    mktorrent
    flac2all
  ];
}
