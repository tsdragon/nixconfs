{
  pkgs,
  lib,
  ...
}: let
  spellcheckDicts = with pkgs.hunspellDicts; [
    en_CA
    en_US
  ];
in {
  services = {
    displayManager.plasma-login-manager.enable = true;
    desktopManager.plasma6.enable = true;
  };

  xdg.portal = {
    enable = true;
    # WORKAROUND(2026-06-10): Force KDE as the preferred portal while retaining
    # GTK for applications that do not work correctly through the KDE backend.
    # Re-test the fallback after major Plasma and portal updates.
    extraPortals = [
      pkgs.kdePackages.xdg-desktop-portal-kde
      pkgs.xdg-desktop-portal-gtk
    ];
    configPackages = [pkgs.kdePackages.plasma-workspace];
  };

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    kate
    konsole
    oxygen
    elisa
    khelpcenter
    discover
  ];

  environment.systemPackages = with pkgs;
    [
      kde-gruvbox
      whitesur-kde
      hunspell
      qt6.qtwayland
      kdePackages.kcalc
      kdePackages.qtstyleplugin-kvantum
    ]
    ++ spellcheckDicts;

  qt.style = "kvantum";

  environment.sessionVariables.DICPATH =
    lib.makeSearchPath "share/hunspell" spellcheckDicts;

  programs = {
    partition-manager.enable = true;
    kdeconnect.enable = true;
  };
}
