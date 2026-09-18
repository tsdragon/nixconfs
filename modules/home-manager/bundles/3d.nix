{pkgs, ...}: let
  # WORKAROUND(2026-07-08): The nixpkgs desktop entry omits Lychee's custom
  # auth URL scheme, so browser-based login cannot redirect back into the app.
  lycheeDesktop = pkgs.makeDesktopItem {
    name = "lycheeslicer";
    desktopName = "LycheeSlicer";
    genericName = "Resin Slicer";
    exec = "${pkgs.lycheeslicer}/bin/lycheeslicer %U";
    icon = "lycheeslicer";
    comment = "All-in-one 3D slicer for Resin and Filament";
    mimeTypes = [
      "model/stl"
      "x-scheme-handler/lycheeslicer"
    ];
    categories = ["Graphics"];
    keywords = [
      "STL"
      "Slicer"
      "Printing"
    ];
    startupWMClass = "LycheeSlicer";
  };
in {
  imports = [
    ../apps/orca-slicer.nix
  ];

  home.packages = with pkgs; [
    blender
    openscad
    unityhub
    lycheeslicer
    lycheeDesktop
  ];

  xdg.mimeApps = {
    enable = true;
    associations.added."x-scheme-handler/lycheeslicer" = "lycheeslicer.desktop";
    defaultApplications."x-scheme-handler/lycheeslicer" = "lycheeslicer.desktop";
  };
}
