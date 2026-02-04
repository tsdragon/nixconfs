{ config, lib, pkgs, ... }:

let
  cfg = config.programs.vnyan;

  envExports = lib.concatStringsSep "\n"
    (lib.mapAttrsToList (name: value: "export ${name}=\"${value}\"") cfg.environment);

  vnyanWrapper = pkgs.writeShellScriptBin "vnyan" ''
    set -euo pipefail
    export WINEPREFIX="${cfg.prefix}"
    export WINEARCH=win64
    ${envExports}
    exe_path="${cfg.exePath}"
    if [ "${lib.boolToString cfg.autoDetectExe}" = "true" ] && [ ! -f "$exe_path" ]; then
      for candidate in \
        "$WINEPREFIX/drive_c/Program Files/VNyan/VNyan.exe" \
        "$WINEPREFIX/drive_c/Program Files (x86)/VNyan/VNyan.exe" \
        "$WINEPREFIX/drive_c/Program Files/Vnyan/Vnyan.exe" \
        "$WINEPREFIX/drive_c/Program Files (x86)/Vnyan/Vnyan.exe"
      do
        if [ -f "$candidate" ]; then
          exe_path="$candidate"
          break
        fi
      done
    fi
    exec ${cfg.winePackage}/bin/wine "$exe_path" "$@"
  '';

  vnyanInstall = pkgs.writeShellScriptBin "vnyan-install" ''
    set -euo pipefail
    if [ "$#" -lt 1 ]; then
      echo "Usage: vnyan-install /path/to/VnyanInstaller.exe" >&2
      exit 1
    fi
    export WINEPREFIX="${cfg.prefix}"
    export WINEARCH=win64
    ${envExports}
    mkdir -p "$WINEPREFIX"
    exec ${cfg.winePackage}/bin/wine "$1"
  '';

  vnyanSetup = pkgs.writeShellScriptBin "vnyan-setup" ''
    set -euo pipefail
    export WINEPREFIX="${cfg.prefix}"
    export WINEARCH=win64
    ${envExports}
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
      default = "${config.xdg.dataHome}/vnyan/prefix/drive_c/Program Files/VNyan/VNyan.exe";
      description = "Path to Vnyan.exe inside the prefix.";
    };

    autoDetectExe = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to fall back to common install paths if exePath is missing.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        WINE_DISABLE_RAWINPUT = "1";
      };
      description = "Environment variables exported when running Vnyan.";
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
