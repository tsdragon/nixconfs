{
  pkgs,
  lib,
  ...
}: let
  wallpaperNasMount = "/home/tal/nas/main";
  wallpaperSource = "${wallpaperNasMount}/Pictures/Wallpapers";
  wallpaperCache = "/home/tal/.wallpapers";
  syncWallpaperCache = ''
    set -euo pipefail

    nas_mount=${lib.escapeShellArg wallpaperNasMount}
    source_dir=${lib.escapeShellArg wallpaperSource}
    target_dir=${lib.escapeShellArg wallpaperCache}

    if ! findmnt -rn --target "$nas_mount" --types cifs >/dev/null; then
      exit 0
    fi

    if [ ! -d "$source_dir" ]; then
      exit 0
    fi

    mkdir -p "$target_dir"
    rsync -a --delete --chmod=D755,F644 --info=stats2 "$source_dir"/ "$target_dir"/
  '';
in {
  systemd.tmpfiles.rules = [
    "d ${wallpaperCache} 0755 tal users -"
  ];

  systemd.services = {
    tal-wallpaper-cache-sync = {
      description = "Sync Tal's local wallpaper cache from the NAS";
      wantedBy = ["home-tal-nas-main.mount"];
      after = ["home-tal-nas-main.mount"];
      path = with pkgs; [
        coreutils
        rsync
        util-linux
      ];
      serviceConfig = {
        Type = "oneshot";
        User = "tal";
        Group = "users";
        Nice = 10;
        IOSchedulingClass = "idle";
      };
      script = syncWallpaperCache;
    };

    tal-wallpaper-cache-sync-shutdown = {
      description = "Sync Tal's local wallpaper cache from the NAS before shutdown";
      wantedBy = ["shutdown.target"];
      before = [
        "shutdown.target"
        "umount.target"
        "network.target"
      ];
      after = ["home-tal-nas-main.mount"];
      unitConfig.DefaultDependencies = false;
      path = with pkgs; [
        coreutils
        rsync
        util-linux
      ];
      serviceConfig = {
        Type = "oneshot";
        User = "tal";
        Group = "users";
        Nice = 10;
        IOSchedulingClass = "idle";
        TimeoutStartSec = "2min";
      };
      script = syncWallpaperCache;
    };
  };
}
