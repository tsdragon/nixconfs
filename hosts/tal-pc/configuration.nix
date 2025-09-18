{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/base/default.nix
    ../../modules/system/base/nvidia.nix
    ../../modules/system/users/tal.nix
    ../../modules/system/bundles/general-desktop.nix
    ../../modules/system/desktops/plasma.nix
    ../../modules/system/bundles/gaming.nix
    ../../modules/system/bundles/motu.nix
    ../../modules/system/bundles/qmk.nix
    ../../modules/system/base/sops.nix
    ../../modules/system/services/odrive.nix
    ../../modules/system/services/ai.nix
  ];

  networking.hostName = "tal-pc";

  networking.networkmanager.ensureProfiles.profiles = {
    br0 = {
      connection = {
        id = "br0";
        type = "bridge";
        interface-name = "br0";
        autoconnect = true;
      };
      ipv4.method = "auto";
      ipv6.method = "auto";
      bridge.stp = "false";
    };

    "eno1->br0" = {
      connection = {
        id = "eno1->br0";
        type = "ethernet";
        interface-name = "eno1";
        master = "br0";
        port-type = "bridge";
        autoconnect = true;
      };
      ipv4.method = "disabled";
      ipv6.method = "disabled";
    };

    "eno2->br0" = {
      connection = {
        id = "eno2->br0";
        type = "ethernet";
        interface-name = "eno2";
        master = "br0";
        port-type = "bridge";
        autoconnect = true;
      };
      ipv4.method = "disabled";
      ipv6.method = "disabled";
    };
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
  
  programs = {
    winbox.enable = true;
    adb.enable = true;
  };

  services.pcscd.enable = true;

  nixpkgs.overlays = [ (import ../../overlays/av1-overlay.nix) ];

  environment.systemPackages = with pkgs; [
    cifs-utils
    androidenv.androidPkgs.platform-tools
    yubioath-flutter
    aria2
  ];
  
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}