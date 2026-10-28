{pkgs, ...}: let
  version = "2.4.2";
  src = pkgs.fetchurl {
    url = "https://github.com/OrcaSlicer/OrcaSlicer/releases/download/v${version}/OrcaSlicer_Linux_AppImage_Ubuntu2404_V${version}.AppImage";
    hash = "sha256:d12fb8c8eac1aecd2dfb6377acd48f994f8fa439ed5292fa532dd82880f029fd";
  };
  contents = pkgs.appimageTools.extract {
    pname = "orca-slicer";
    inherit version src;
  };
  orca-slicer = pkgs.appimageTools.wrapType2 {
    pname = "orca-slicer";
    inherit version src;

    # Upstream's AppImage relies on the host WebKitGTK 4.1 stack.
    extraPkgs = pkgs: [pkgs.webkitgtk_4_1 pkgs.libsoup_3];
    profile = ''
      # WORKAROUND(2026-10-26): Native Wayland falls back to llvmpipe on NVIDIA.
      export GDK_BACKEND=x11
      export ZINK_DISABLE_OVERRIDE=1
      # WORKAROUND(2026-10-23): Avoid a blank WebKit home page on NVIDIA.
      export WEBKIT_DISABLE_DMABUF_RENDERER=1
    '';

    extraInstallCommands = ''
      install -Dm644 ${contents}/com.orcaslicer.OrcaSlicer.desktop \
        "$out/share/applications/com.orcaslicer.OrcaSlicer.desktop"
      substituteInPlace "$out/share/applications/com.orcaslicer.OrcaSlicer.desktop" \
        --replace-fail 'Exec=AppRun' "Exec=$out/bin/orca-slicer"
      install -Dm644 ${contents}/OrcaSlicer.png \
        "$out/share/icons/hicolor/512x512/apps/OrcaSlicer.png"
    '';
  };
in {
  home.packages = [orca-slicer];
}
