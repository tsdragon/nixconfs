{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.roon-client;

  envExports =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}") cfg.environment);

  commonWineEnv = ''
    export WINEPREFIX="${cfg.prefix}"
    export WINEARCH=win64
    export WINE="${cfg.wineBinaryForWinetricks}"
    export WINESERVER="${cfg.winePackage}/bin/wineserver"
    ${envExports}
    ${pkgs.coreutils}/bin/mkdir -p "$WINEPREFIX"
  '';

  roonWrapper = pkgs.writeShellScriptBin "roon-client" ''
    set -euo pipefail
    ${commonWineEnv}

    exe_path="${cfg.exePath}"
    if [ "${lib.boolToString cfg.autoDetectExe}" = "true" ] && [ ! -f "$exe_path" ]; then
      candidates=(
        "$WINEPREFIX/drive_c/users/$USER/AppData/Local/Roon/Application/Roon.exe"
        "$WINEPREFIX/drive_c/users/${config.home.username}/AppData/Local/Roon/Application/Roon.exe"
        "$WINEPREFIX/drive_c/Program Files/Roon/Application/Roon.exe"
        "$WINEPREFIX/drive_c/Program Files/Roon/Roon.exe"
        "$WINEPREFIX/drive_c/Program Files (x86)/Roon/Application/Roon.exe"
        "$WINEPREFIX/drive_c/Program Files (x86)/Roon/Roon.exe"
      )

      for candidate in "''${candidates[@]}"; do
        if [ -f "$candidate" ]; then
          exe_path="$candidate"
          break
        fi
      done

      if [ ! -f "$exe_path" ] && [ -d "$WINEPREFIX/drive_c/users" ]; then
        found="$(${pkgs.findutils}/bin/find "$WINEPREFIX/drive_c/users" -path '*/AppData/Local/Roon/Application/Roon.exe' -print -quit 2>/dev/null || true)"
        if [ -n "$found" ]; then
          exe_path="$found"
        fi
      fi
    fi

    if [ ! -f "$exe_path" ]; then
      echo "Roon is not installed in this Wine prefix yet." >&2
      echo "Run: roon-setup && roon-install" >&2
      echo "Expected: $exe_path" >&2
      exit 1
    fi

    ${pruneWineDesktopEntries}
    exec ${cfg.winePackage}/bin/wine "$exe_path" "$@"
  '';

  syncRoonIcons = ''
    target_name=${lib.escapeShellArg "${cfg.icon}.png"}
    for source_icon in ${lib.escapeShellArg "${config.home.homeDirectory}/.local/share/icons/hicolor"}/*x*/apps/718A_Roon.0.png; do
      [ -e "$source_icon" ] || continue
      size="$(${pkgs.coreutils}/bin/basename "$(${pkgs.coreutils}/bin/dirname "$(${pkgs.coreutils}/bin/dirname "$source_icon")")")"
      target_dir=${lib.escapeShellArg "${config.home.homeDirectory}/.local/share/icons/hicolor"}/"$size"/apps
      ${pkgs.coreutils}/bin/mkdir -p "$target_dir"
      ${pkgs.coreutils}/bin/cp -f "$source_icon" "$target_dir/$target_name"
    done
  '';

  pruneWineDesktopEntries = ''
    ${pkgs.coreutils}/bin/rm -f \
      ${lib.escapeShellArg "${config.home.homeDirectory}/.local/share/applications/wine/Programs/Roon.desktop"} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/.local/share/applications/wine/Programs/RoonServer.desktop"}
    ${pkgs.coreutils}/bin/rmdir --ignore-fail-on-non-empty \
      ${lib.escapeShellArg "${config.home.homeDirectory}/.local/share/applications/wine/Programs"} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/.local/share/applications/wine"} 2>/dev/null || true
  '';

  roonInstall = pkgs.writeShellScriptBin "roon-install" ''
    set -euo pipefail
    ${commonWineEnv}

    installer="''${1:-}"
    cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/roon"
    ${pkgs.coreutils}/bin/mkdir -p "$cache_dir"

    if [ -z "$installer" ]; then
      installer="$cache_dir/RoonInstaller64.exe"
      echo "Downloading Roon installer from ${cfg.installerUrl}"
      ${pkgs.curl}/bin/curl --fail --location --show-error --output "$installer.tmp" "${cfg.installerUrl}"
      ${pkgs.coreutils}/bin/mv "$installer.tmp" "$installer"
    elif [[ "$installer" =~ ^https?:// ]]; then
      url="$installer"
      installer="$cache_dir/''${url##*/}"
      echo "Downloading Roon installer from $url"
      ${pkgs.curl}/bin/curl --fail --location --show-error --output "$installer.tmp" "$url"
      ${pkgs.coreutils}/bin/mv "$installer.tmp" "$installer"
    fi

    ${cfg.winePackage}/bin/wine "$installer"
    ${syncRoonIcons}
    ${pruneWineDesktopEntries}
  '';

  roonSetup = pkgs.writeShellScriptBin "roon-setup" ''
    set -euo pipefail
    ${commonWineEnv}

    ${cfg.winePackage}/bin/wineboot -u
    ${lib.optionalString (cfg.winetricksPackages != []) ''
      ${cfg.winetricksPackage}/bin/winetricks -q ${lib.escapeShellArgs cfg.winetricksPackages}
    ''}
    ${cfg.wineBinaryForWinetricks} winecfg -v ${lib.escapeShellArg cfg.windowsVersion}

    echo "Roon Wine prefix prepared in $WINEPREFIX"
    echo "Install or update Roon with: roon-install"
  '';

  roonWinecfg = pkgs.writeShellScriptBin "roon-winecfg" ''
    set -euo pipefail
    ${commonWineEnv}
    exec ${cfg.winePackage}/bin/winecfg "$@"
  '';

  roonDesktop = pkgs.makeDesktopItem {
    name = "roon-client";
    desktopName = "Roon";
    genericName = "Music Player";
    exec = "${roonWrapper}/bin/roon-client %u";
    icon = cfg.icon;
    mimeTypes = ["x-scheme-handler/roon"];
    categories = ["AudioVideo" "Player"];
    comment = "Run Roon for Windows with Wine";
    startupNotify = true;
  };
in {
  options.programs.roon-client = {
    enable = lib.mkEnableOption "Roon desktop client through Wine";

    winePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.wineWowPackages.stagingFull;
      description = "Wine package used to run the Windows Roon client.";
    };

    wineBinaryForWinetricks = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.winePackage}/bin/.wine";
      description = "Real Wine loader used by winetricks. Nix's wine wrapper script can confuse winetricks architecture detection.";
    };

    winetricksPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.winetricks;
      description = "Winetricks package used to prepare the Roon Wine prefix.";
    };

    prefix = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/roon/prefix";
      description = "Wine prefix path used for Roon.";
    };

    installerUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://download.roonlabs.net/builds/RoonInstaller64.exe";
      description = "Default Roon for Windows installer URL used by roon-install.";
    };

    exePath = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/roon/prefix/drive_c/users/${config.home.username}/AppData/Local/Roon/Application/Roon.exe";
      description = "Path to Roon.exe inside the Wine prefix.";
    };

    autoDetectExe = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to fall back to common Roon install paths if exePath is missing.";
    };

    icon = lib.mkOption {
      type = lib.types.str;
      default = "roon";
      description = "Icon name used for the Roon desktop entry.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1";
        WINEDEBUG = "-all";
      };
      description = "Environment variables exported when running Roon under Wine.";
    };

    winetricksPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["win10" "corefonts" "dotnet48"];
      description = "Winetricks verbs to install in the Roon Wine prefix.";
    };

    windowsVersion = lib.mkOption {
      type = lib.types.str;
      default = "win10";
      description = "Windows compatibility version to force after installing winetricks dependencies.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.winePackage
      cfg.winetricksPackage
      roonWrapper
      roonInstall
      roonSetup
      roonWinecfg
      roonDesktop
    ];

    xdg.mimeApps = {
      enable = true;
      associations.added."x-scheme-handler/roon" = "roon-client.desktop";
      defaultApplications."x-scheme-handler/roon" = "roon-client.desktop";
    };

    systemd.user.services.roon-pipewire-loopback = {
      Unit = {
        Description = "Route Roon Bridge ALSA loopback into PipeWire";
        After = [
          "pipewire.service"
          "pipewire-pulse.service"
          "wireplumber.service"
        ];
        Wants = [
          "pipewire.service"
          "pipewire-pulse.service"
          "wireplumber.service"
        ];
        PartOf = ["pipewire.service"];
      };

      Service = {
        ExecStartPre = "${pkgs.coreutils}/bin/test -e /proc/asound/RoonPipeWire";
        ExecStart = "${pkgs.alsa-utils}/bin/alsaloop -C hw:RoonPipeWire,1,0 -P pipewire -t 100000 -S 5 -A 5 -n";
        Restart = "on-failure";
        RestartSec = 2;
      };

      Install.WantedBy = ["default.target"];
    };

    home.activation.pruneRoonWineDesktopEntries = lib.hm.dag.entryAfter ["writeBoundary"] pruneWineDesktopEntries;
    home.activation.syncRoonIcons = lib.hm.dag.entryAfter ["writeBoundary"] syncRoonIcons;
  };
}
