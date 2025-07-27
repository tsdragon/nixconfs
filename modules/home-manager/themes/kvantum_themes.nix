{ config, pkgs, lib, ... }:

{
  home.file = {
    ".config/kvantum/Sweet-transparent-toolbar/Sweet-transparent-toolbar.kvconfig" = {
      source = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/EliverLara/Sweet/c9e49566fffce53109664b0b9670915142225ee2/kde/Kvantum/Sweet-transparent-toolbar/Sweet-transparent-toolbar.kvconfig";
        sha256 = "sha256-P2GPsm+Mr8UrM06B75mMD0qAV74hdGEe7KxNxBrrLqM=";
      };
      recursive = true;
    };

    ".config/kvantum/Sweet/Sweet.kvconfig" = {
      source = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/EliverLara/Sweet/c9e49566fffce53109664b0b9670915142225ee2/kde/Kvantum/Sweet/Sweet.kvconfig";
        sha256 = "sha256-qVDMZ+lWhLyRmlSX4KKtHEwz92S7UqxaXPPlNAdIswg=";
      };
      recursive = true;
    };
  };
}