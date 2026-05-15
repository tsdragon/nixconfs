{
  pkgs,
  inputs,
  ...
}: {
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

  services.roon-bridge = {
    enable = true;
    openFirewall = true;
  };

  networking.firewall = {
    enable = true;
    # Roon Bridge opens per-output RAAT listeners in the ephemeral range:
    # TCP for audio and UDP for the clock. Limit those dynamic connections to
    # the Roon Core observed in RAAT logs.
    extraCommands = ''
      iptables -A nixos-fw -i br0 -s 192.168.1.241/32 -p tcp --dport 32768:60999 -j nixos-fw-accept
      iptables -A nixos-fw -i br0 -s 192.168.1.241/32 -p udp --dport 32768:60999 -j nixos-fw-accept
    '';
    # ifacialmocap Ports
    allowedUDPPorts = [49983];
    # Optional (usually not needed for realtime streaming):
    # allowedTCPPorts = [ 49987 ];
  };

  networking.networkmanager.settings.main.no-auto-default = "*";

  networking.networkmanager.ensureProfiles.profiles = {
    br0 = {
      connection = {
        id = "br0";
        type = "bridge";
        interface-name = "br0";
        autoconnect = true;
        autoconnect-priority = 100;
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
        autoconnect-priority = 100;
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
        autoconnect-priority = 100;
      };
      ipv4.method = "disabled";
      ipv6.method = "disabled";
    };
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    # Temporary pin: NVIDIA 580.119.02 in current nixpkgs does not build against 6.19 yet.
    #kernelPackages = pkgs.linuxPackages_6_18;

    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 1; # prune old entries to keep the EFI partition small
        consoleMode = "max"; # keep the pre-kernel framebuffer as close to native as possible
      };
      efi.canTouchEfiVariables = true;
    };

    # Prevent the iGPU (amdgpu) from binding DRM so only the NVIDIA dGPU drives displays.
    blacklistedKernelModules = ["amdgpu"];

    initrd = {
      systemd.enable = true;
      kernelModules = ["nvidia" "nvidia_modeset" "nvidia_drm" "nvidia_uvm"];
    };

  };

  systemd = {
    settings.Manager = {
      DefaultLimitNOFILE = "524288";
    };

    # Plasma/Wayland can pass many DRM sync file descriptors between processes;
    # avoid the low 1024 soft limit that showed up in the journal.
    user.extraConfig = ''
      DefaultLimitNOFILE=524288
    '';
  };

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
  };

  programs = {
    winbox.enable = true;
    adb.enable = true;
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

  nixpkgs.overlays = [
    (import ../../overlays/av1-overlay.nix)
    (import ../../overlays/roon-bridge.nix)
  ];

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
