{config, ...}: {
  hardware.graphics.enable = true;

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    # Modesetting is required.
    modesetting.enable = true;

    # WORKAROUND(2026-06-10): Preserve all VRAM to avoid corruption or crashes
    # after resume. Re-test without this after major NVIDIA driver updates.
    powerManagement.enable = true;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # WORKAROUND(2026-06-10): The open kernel module has been unreliable with
    # KWin atomic modesets. Re-test it after major NVIDIA or Plasma updates.
    # Support for open driver is limited to the Turing and later architectures. Full list of
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # Only available from driver 515.43.04+
    open = false;

    nvidiaSettings = true;

    # Prefer the long-lived branch for fewer regressions.
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };
}
