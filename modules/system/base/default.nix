{ config, pkgs, lib, ... }:

{
  nix.settings = {
    experimental-features = "nix-command flakes";
  };

  nix.gc = {
    automatic = true;
    randomizedDelaySec = "14m";
    options = "--delete-older-than 10d";
  };

  boot.supportedFilesystems = [ "ntfs" ];

  time.timeZone = "America/Edmonton";
  i18n.defaultLocale = "en_CA.UTF-8";

  networking.networkmanager.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    wget
    tree
    nil
    less
    tldr
    exfatprogs
    sops
    nfs-utils
    p7zip
    unrar
  ];

  programs = {
    zsh.enable = true;
    git.enable = true;
    screen.enable = true;
    bat.enable = true;
    zoxide.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
    gvfs = {
      enable = true;
    };
  };
}
