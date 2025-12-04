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
  ] ++ spellcheckDicts;

  qt.style = "kvantum";

  environment.sessionVariables.DICPATH =
    lib.makeSearchPath "share/hunspell" spellcheckDicts;

  programs.partition-manager.enable = true;
}
