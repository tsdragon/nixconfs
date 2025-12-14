{ config, pkgs, lib, ... }:

let
  spellcheckDicts = with pkgs.hunspellDicts; [
    en_CA
    en_US
  ];
in
{
  services = {
    displayManager.sddm.enable = true;
    desktopManager.plasma6.enable = true;
  };

  xdg.portal = {
    enable = true;
    # Force the KDE portal and keep GTK around for fallback-only cases.
    extraPortals = [
      pkgs.kdePackages.xdg-desktop-portal-kde
      pkgs.xdg-desktop-portal-gtk
    ];
    configPackages = [ pkgs.kdePackages.plasma-workspace ];
  };

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    kate
    konsole
    oxygen
    elisa
    khelpcenter
    discover
  ];

  environment.systemPackages = with pkgs; [
    kde-gruvbox
    whitesur-kde
    kdePackages.akonadi
    kdePackages.akonadiconsole
    kdePackages.akonadi-search
    kdePackages.qtstyleplugin-kvantum
    hunspell
    qt6.qtwayland
  ] ++ spellcheckDicts;

  qt.style = "kvantum";

  environment.sessionVariables.DICPATH =
    lib.makeSearchPath "share/hunspell" spellcheckDicts;

  programs.partition-manager.enable = true;
}
