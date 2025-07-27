{ config, pkgs, ... }:

{
  home.packages = [ pkgs.cifs-utils ];

  systemd.user.mounts.home-tal-nas-main = {
    Unit = {
      Description = "Mount main fileshare from NAS";
      After = [ "network-online.target" ];
    };
    Mount = {
      What = "//192.168.1.200/Main Fileshare/";
      Where = "${config.home.homeDirectory}/nas/main";
      Type = "cifs";
      Options = "credentials=${config.sops.templates."cifs_creds".path},uid=1000,gid=1010,iocharset=utf8,vers=3.1.1,x-mount.mkdir";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.automounts.home-tal-nas-main = {
    Automount = {
      Where = "${config.home.homeDirectory}/nas/main";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}