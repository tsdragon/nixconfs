{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/base/default.nix
    ../../modules/system/base/nvidia.nix
    ../../modules/system/users/tal.nix
    ../../modules/system/bundles/general-desktop.nix
    ../../modules/system/bundles/virtualization.nix
    ../../modules/system/desktops/plasma.nix
    ../../modules/system/bundles/gaming.nix
    ../../modules/system/bundles/desktop-audio.nix
    ../../modules/system/bundles/qmk.nix
    ../../modules/system/base/sops.nix
    ../../modules/system/services/odrive.nix
    ../../modules/system/services/ai.nix
  ];

  networking.hostName = "tal-pc";

  networking.firewall = {
    enable = true;
    allowedUDPPorts = [ 49983 ];
    # Optional (usually not needed for realtime streaming):
    # allowedTCPPorts = [ 49987 ];
  };

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

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 1; # prune old entries to keep the EFI partition small
      };
      efi.canTouchEfiVariables = true;
    };

    # Prevent the iGPU (amdgpu) from binding DRM so only the NVIDIA dGPU drives displays.
    blacklistedKernelModules = [ "amdgpu" ];

    initrd = {
      kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_drm" "nvidia_uvm" ];
    };

    plymouth = {
      enable = true;
      theme = "dna";
      themePackages = with pkgs; [
        # By default we would install all themes
        (adi1090x-plymouth-themes.override {
          selected_themes = [ "dna" ];
        })
      ];
    };

    # Enable "Silent boot"
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
      "video=DP-0:5120x1440@60e"
    ];
    # Hide the OS choice for bootloaders.
    # It's still possible to open the bootloader list by pressing any key
    # It will just not appear on screen unless a key is pressed
    loader.timeout = 0;
  };

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
  };
  
  programs = {
    winbox.enable = true;
  };

  services = {
    pcscd.enable = true;
    hardware.bolt.enable = true;
    fwupd.enable = true;
    fstrim.enable = true;
    flatpak = {
      enable = true;
      uninstallUnmanaged = true;
      update.auto.enable = true;
      update.onActivation = true;
      packages = [
        "com.parsecgaming.parsec"
      ];
    };
  };

  nixpkgs.overlays = [ (import ../../overlays/av1-overlay.nix) ];

  environment.systemPackages = with pkgs; [
    rpi-imager
    cifs-utils
    android-tools
    yubioath-flutter
    aria2
    qpwgraph
    helvum
    carla
    easyeffects
    lsp-plugins
    x42-plugins
    zam-plugins
    inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop-with-fhs
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
