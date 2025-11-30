{ config, pkgs, lib, ... }:

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
  ];

  qt.style = "kvantum";

  programs.partition-manager.enable = true;
}
