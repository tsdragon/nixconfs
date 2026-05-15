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
in {
  home.packages = [
    parsecNative
  ];

  home.file.".local/share/applications/com.parsecgaming.parsec.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Parsec (Flatpak)
    GenericName=Parsec
    Icon=com.parsecgaming.parsec
    Exec=flatpak run --branch=stable --arch=x86_64 --command=/app/bin/parsec --file-forwarding com.parsecgaming.parsec @@u %u @@
    Categories=Game;
    StartupWMClass=parsecd
    X-Flatpak=com.parsecgaming.parsec
  '';
}
