{pkgs, ...}: {
  home.packages = [
    (pkgs.telegram-desktop.overrideAttrs (oldAttrs: {
      # Avoid NVIDIA GBM failures while retaining compositing for mini app view transitions.
      qtWrapperArgs = oldAttrs.qtWrapperArgs ++ [
        "--set" "WEBKIT_DMABUF_RENDERER_FORCE_SHM" "1"
        "--set" "WEBKIT_SKIA_ENABLE_CPU_RENDERING" "1"
      ];
    }))
    pkgs.discord
  ];
}
