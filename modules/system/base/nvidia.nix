{
  config,
  lib,
  pkgs,
  ...
}: {
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
    package = let
      driver = config.boot.kernelPackages.nvidiaPackages.production;
    in
      # WORKAROUND(2026-09-26): 595.71.05 needs the Linux 7.2 strncpy and DRM
      # compatibility fixes. Remove when production includes them.
      driver.overrideAttrs (old: {
        passthru =
          old.passthru
          // {
            mod = driver.mod.overrideAttrs (oldMod:
              lib.optionalAttrs (driver.version == "595.71.05" && lib.versionAtLeast config.boot.kernelPackages.kernel.version "7.2") {
                patches =
                  (oldMod.patches or [])
                  ++ [
                    (pkgs.fetchurl {
                      url = "https://raw.githubusercontent.com/CachyOS/CachyOS-PKGBUILDS/94bcd86886298f7798837a38dc1ff361d60a9c8d/nvidia/nvidia-utils/0001-make-Add-support-for-7.2-Kernel.patch";
                      hash = "sha256-hdklzeaY0s/0RME+CtQoddwOuTkSh+/jNdDD6t7cC48=";
                    })
                  ];
                # The patch targets kernel-open/; this source starts below it.
                patchFlags = ["-p2"];
              });
          };
      });
  };
}
