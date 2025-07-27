{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/home-manager/base/default.nix
    ../../modules/home-manager/base/identity.nix
    ../../modules/home-manager/apps/zsh.nix
    ../../modules/home-manager/apps/firefox.nix
    ../../modules/home-manager/apps/kitty.nix
    ../../modules/home-manager/apps/git.nix
  ];

  nixpkgs.config.allowUnfree = true;

  home = {
    username = "tal";
    homeDirectory = "/home/tal";
  };

  programs = {
    home-manager.enable = true;
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  home.stateVersion = "24.05"; # Match your NixOS state version
}
