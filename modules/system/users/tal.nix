{
  config,
  pkgs,
  ...
}: let
  nasAddress = "192.168.1.200";
  commonCifsOptions = [
    "_netdev"
    "noauto"
    "x-systemd.automount"
    "x-systemd.requires=tal-nas-online.service"
    "x-systemd.after=tal-nas-online.service"
    "x-systemd.requires=network-online.target"
    "x-systemd.after=network-online.target"
    "x-systemd.idle-timeout=0"
    "credentials=${config.sops.templates."cifs_creds".path}"
    "uid=1000"
    "gid=1010"
    "iocharset=utf8"
    "vers=3.1.1"
    "nofail"
  ];
in {
  imports = [
    ../services/wallpaper-cache.nix
  ];

  users.groups.plugdev = {};
  users.groups.urf = {gid = 1010;};

  users.users = {
    tal = {
      isNormalUser = true;
      home = "/home/tal";
      name = "tal";
      description = "Tal";
      extraGroups = [
        "wheel"
        "networkmanager"
        "libvirtd"
        "docker"
        "adbusers"
        "flatpak"
        "qemu"
        "kvm"
        "audio"
        "video"
        "plugdev"
        "aria2"
        "urf"
        "dialout"
      ];
      initialPassword = "your-password"; # Replace with a secure password
      shell = pkgs.zsh;
    };
  };

  # Mount NAS main fileshares for user tal
  fileSystems = {
    "/home/tal/nas/main" = {
      device = "//192.168.1.200/Main Fileshare";
      fsType = "cifs";
      options = commonCifsOptions;
    };

    "/home/tal/nas/media" = {
      device = "//192.168.1.200/Media";
      fsType = "cifs";
      options = commonCifsOptions;
    };

    # You can even add a one-off option if needed
    #"/home/tal/nas/readonly" = {
    #  device = "//192.168.1.200/ReadOnlyShare";
    #  fsType = "cifs";
    #  # Use the ++ operator to append to the list
    #  options = commonCifsOptions ++ [ "ro" ];
    #};
  };

  security.wrappers."mount.cifs" = {
    source = "${pkgs.cifs-utils}/bin/mount.cifs";
    owner = "root";
    group = "root";
    setuid = true;
  };

  systemd.services.tal-nas-online = {
    description = "Wait for Tal's NAS to be reachable";
    wants = ["network-online.target"];
    after = ["network-online.target"];
    startLimitIntervalSec = 0;
    path = with pkgs; [
      coreutils
      iputils
    ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "30s";
    };
    script = ''
      for attempt in $(seq 1 30); do
        if ping -c 1 -W 1 ${nasAddress} >/dev/null; then
          exit 0
        fi
        sleep 1
      done

      exit 1
    '';
  };

  systemd.units = {
    "home-tal-nas-main.automount" = {
      overrideStrategy = "asDropin";
      text = ''
        [Unit]
        StartLimitIntervalSec=0
      '';
    };
    "home-tal-nas-main.mount" = {
      overrideStrategy = "asDropin";
      text = ''
        [Unit]
        StartLimitIntervalSec=0
      '';
    };
    "home-tal-nas-media.automount" = {
      overrideStrategy = "asDropin";
      text = ''
        [Unit]
        StartLimitIntervalSec=0
      '';
    };
    "home-tal-nas-media.mount" = {
      overrideStrategy = "asDropin";
      text = ''
        [Unit]
        StartLimitIntervalSec=0
      '';
    };
  };

  # Enable passwordless sudo for user tal
  security.sudo.extraRules = [
    {
      users = ["tal"];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
}
