{pkgs, ...}: {
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
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
