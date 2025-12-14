{ config, pkgs, lib, ... }:

{
  hardware.graphics = {
    enable = true;
    # VA-API shim for NVDEC/NVENC so browsers/media players can use the NVIDIA GPU.
    extraPackages = with pkgs; [
      nvidia-vaapi-driver
      egl-wayland
    ];
    # Wayland EGL platform for 32-bit clients (e.g., Steam runtime) so they can talk to the driver.
    extraPackages32 = with pkgs.pkgsi686Linux; [ egl-wayland ];
  };

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead 
    # of just the bare essentials.
    powerManagement.enable = true;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use proprietary kernel module (open module can flake with KWin atomic modesets).
    # Support fir open driver (if you choose touse it) is limited to the Turing and later architectures. Full list of 
    # supported GPUs is at: 
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus 
    # Only available from driver 515.43.04+
    open = false;

    nvidiaSettings = true;
    
    # Prefer the long-lived branch for fewer regressions.
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };
}
