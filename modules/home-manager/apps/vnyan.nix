{ config, lib, pkgs, ... }:

let
  cfg = config.programs.vnyan;

  vnyanWrapper = pkgs.writeShellScriptBin "vnyan" ''
    set -euo pipefail
    export WINEPREFIX="${cfg.prefix}"
    export WINEARCH=win64
    exec ${cfg.winePackage}/bin/wine "${cfg.exePath}" "$@"
  '';

  vnyanInstall = pkgs.writeShellScriptBin "vnyan-install" ''
    set -euo pipefail
    if [ "$#" -lt 1 ]; then
      echo "Usage: vnyan-install /path/to/VnyanInstaller.exe" >&2
      exit 1
    fi
    export WINEPREFIX="${cfg.prefix}"
    export WINEARCH=win64
    mkdir -p "$WINEPREFIX"
    exec ${cfg.winePackage}/bin/wine "$1"
  '';

  vnyanSetup = pkgs.writeShellScriptBin "vnyan-setup" ''
    set -euo pipefail
    export WINEPREFIX="${cfg.prefix}"
    export WINEARCH=win64
    mkdir -p "$WINEPREFIX"
    ${cfg.winePackage}/bin/wineboot -u
    ${cfg.winetricksPackage}/bin/winetricks -q ${lib.escapeShellArgs cfg.winetricksPackages}
    echo "Vnyan prefix prepared in $WINEPREFIX"
    echo "Install Vnyan with: vnyan-install /path/to/VnyanInstaller.exe"
  '';

  vnyanDesktop = pkgs.makeDesktopItem {
    name = "vnyan";
    desktopName = "Vnyan";
    exec = "vnyan";
    categories = [ "AudioVideo" "Graphics" "Game" ];
    comment = "Run Vnyan with Wine";
  };
in
{
  options.programs.vnyan = {
    enable = lib.mkEnableOption "Vnyan (Wine wrapper + winetricks helpers)";

    winePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.wineWowPackages.staging;
      description = "Wine package used to run Vnyan.";
    };

    winetricksPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.winetricks;
      description = "Winetricks package used to install Vnyan dependencies.";
    };

    prefix = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/vnyan/prefix";
      description = "Wine prefix path used for Vnyan.";
    };

    exePath = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/vnyan/prefix/drive_c/Program Files/Vnyan/Vnyan.exe";
      description = "Path to Vnyan.exe inside the prefix.";
    };

    winetricksPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "vcrun2019" "dotnet48" ];
      description = "Winetricks verbs to install in the Vnyan prefix.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.winePackage
      cfg.winetricksPackage
      vnyanWrapper
      vnyanInstall
      vnyanSetup
      vnyanDesktop
    ];
  };
}
