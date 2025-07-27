{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/home-manager/base/default.nix
    ../../modules/home-manager/apps/zsh.nix
    ../../modules/home-manager/apps/firefox.nix
    ../../modules/home-manager/apps/kitty.nix
    ../../modules/home-manager/bundles/messaging.nix
    ../../modules/home-manager/bundles/3d.nix
  ];

  nixpkgs.config.allowUnfree = true;

  home = {
    username = "tal";
    homeDirectory = "/home/tal";
  };

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      userName = "Tal";
      userEmail = "tal@steakdrake.co";
    };
  };

  home.packages = with pkgs; [
    parsec-bin
  ];

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  home.stateVersion = "24.11"; # Match your NixOS version
}
