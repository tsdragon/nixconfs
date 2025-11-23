{ config, pkgs, ... }:

let
  version = "3.1.65";
  appimageSha256  = "sha256-AQM04BEdAphACzJ+JR5UE5DQiXTmnKunSorNd5tLjsA=";

  postybirbAppImage = pkgs.fetchurl {
    url    = "https://github.com/mvdicarlo/postybirb-plus/releases/download/v${version}/postybirb-plus-${version}-x86_64.AppImage";
    sha256 = appimageSha256;
  };

  postybirbIcon = pkgs.fetchurl {
    url    = "https://raw.githubusercontent.com/mvdicarlo/postybirb-plus/master/electron-app/packaging-resources/icon.png";
    sha256 = "sha256-iSe3DJh2R3yqoR7GVPijw1T2FvXB8SJEUA1TqL6kH5M=";
  };

  # Wrap the AppImage so Home Manager can install it like a normal package.
  postybirb = pkgs.appimageTools.wrapType2 {
    pname = "postybirb";
    version = version;
    src  = postybirbAppImage;

    extraInstallCommands = ''
      # Create the directories
      mkdir -p $out/share/applications
      mkdir -p $out/share/icons/hicolor/256x256/apps

      # Copy the icon
      cp ${postybirbIcon} $out/share/icons/hicolor/256x256/apps/postybirb.png

      # Create a .desktop file referencing this icon
      cat <<EOF > $out/share/applications/postybirb.desktop
      [Desktop Entry]
      Name=PostyBirb
      Comment=Upload posts to multiple websites
      Exec=postybirb
      Icon=postybirb
      Terminal=false
      Type=Application
      Categories=Network;Application;
      EOF
    '';
  };
in {
  # Expose `postybirb` in your PATH via `home.packages`.
  home.packages = [
    postybirb
  ];
}
