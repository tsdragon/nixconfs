{ pkgs, pkgsUnstable, ... }:
{
  home.packages = with pkgs; [
    pkgsUnstable.exactaudiocopy
    flac
    lame
    mktorrent
    flac2all
  ];
}
