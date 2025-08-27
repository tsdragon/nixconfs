{ pkgs, ... }:

{
  home.packages = with pkgs; [
    svt-av1
    handbrake
    ffmpeg
    mkvtoolnix
    kdenlive
  ];
}
