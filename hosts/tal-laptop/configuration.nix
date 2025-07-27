{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/base/default.nix
    ../../modules/system/users/tal.nix
    ../../modules/system/bundles/general-desktop.nix
    ../../modules/system/desktops/gnome.nix
    ../../modules/system/bundles/gaming.nix
  ];

  networking.hostName = "tal-laptop";

  # Bootloader
  boot = {
    loader = {
      grub.enable = true;
      grub.efiSupport = true;
      grub.efiInstallAsRemovable = true;
      grub.devices = [ "nodev" ];
    };
    initrd = {
      luks.devices."luks-26df9c0a-f652-4ebf-a1da-16d5bf610170".device = "/dev/disk/by-uuid/26df9c0a-f652-4ebf-a1da-16d5bf610170";
    };
  };

  programs = {
    winbox.enable = true;
  };

  environment.systemPackages = with pkgs; [
    cifs-utils
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
