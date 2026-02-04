{ config, lib, pkgs, ... }:

{
  programs.steam.enable = true;
  environment.systemPackages = [
    pkgs.r2modman
  ];
}