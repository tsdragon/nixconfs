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

  #services.roon-bridge = {
  #  enable = true;
  #  openFirewall = true;
  #};

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;

    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 3; # keep a small rollback window without filling the EFI partition
        consoleMode = "max"; # keep the pre-kernel framebuffer as close to native as possible
      };
      efi.canTouchEfiVariables = true;
    };

    # WORKAROUND(Permanent): Prevent amdgpu from binding DRM because this host
    # is intended to expose only the NVIDIA dGPU to the display stack. While
    # keeping amdgpu enabled for other purposes such as virtualization.
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

    # WORKAROUND(2026-06-10): Plasma/Wayland can pass enough DRM sync file
    # descriptors to exceed the default soft limit observed in the journal.
    user.extraConfig = ''
      DefaultLimitNOFILE=524288
    '';
  };

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
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

  nixpkgs.overlays = [
    (import ../../overlays/av1-overlay.nix)
    (import ../../overlays/roon-bridge.nix)
  ];

  environment.systemPackages = with pkgs; [
    rpi-imager
    cifs-utils
    android-tools
    yubioath-flutter
    qpwgraph
    crosspipe
    carla
    easyeffects
    lsp-plugins
    x42-plugins
    zam-plugins
    solaar
    calibre
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
