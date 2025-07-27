{ config, pkgs, lib, ... }:
let
  commonCifsOptions = [
    "x-systemd.automount"
    "x-systemd.idle-timeout=0"
    "credentials=${config.sops.templates."cifs_creds".path}"
    "uid=1000"
    "gid=1010"
    "iocharset=utf8"
    "vers=3.1.1"
    "nofail"
  ];
in
{
  users.groups.plugdev = {};
  users.groups.urf = { gid = 1010; };

  users.users = {
    tal = {
      isNormalUser = true;
      home = "/home/tal";
      name = "tal";
      description = "Tal";
      extraGroups = [
        "wheel" "networkmanager" "libvirtd" "docker" "adbusers"
        "flatpak" "qemu" "kvm" "audio" "video" "plugdev" "aria2" "urf"
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

  # Enable passwordless sudo for user tal
  security.sudo.extraRules = [
    {
      users = [ "tal" ];
      commands = [
        { command = "ALL"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];
}
