{ config, lib, pkgs, ... }:

{
  programs.gamemode.enable = true;
  programs.steam.enable = true;

  environment.systemPackages = [
    pkgs.r2modman
  ];
}
