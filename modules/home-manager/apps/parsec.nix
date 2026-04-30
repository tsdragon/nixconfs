{pkgs, ...}: let
  parsecNativeDesktopFile = pkgs.writeText "parsecd.desktop" ''
    [Desktop Entry]
    Name=Parsec (Native)
    GenericName=Parsec
    Comment=Simple, low-latency game streaming.
    Exec=parsecd %u
    Icon=parsecd
    Terminal=false
    Type=Application
    Categories=Game;
  '';

  parsecNative = pkgs.parsec-bin.overrideAttrs (oldAttrs: {
    postInstall =
      (oldAttrs.postInstall or "")
      + ''
        install -Dm0644 ${parsecNativeDesktopFile} $out/share/applications/parsecd.desktop
      '';
  });

  parsecFlatpakDesktop = pkgs.makeDesktopItem {
    name = "com.parsecgaming.parsec";
    desktopName = "Parsec (Flatpak)";
    genericName = "Parsec";
    exec = "flatpak run --branch=stable --arch=x86_64 --command=/app/bin/parsec --file-forwarding com.parsecgaming.parsec @@u %u @@";
    icon = "com.parsecgaming.parsec";
    categories = ["Game"];
    startupWMClass = "parsecd";
    extraConfig = {
      X-Flatpak = "com.parsecgaming.parsec";
    };
  };
in {
  home.packages = [
    parsecNative
    parsecFlatpakDesktop
  ];
}
