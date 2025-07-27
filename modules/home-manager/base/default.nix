{ config, pkgs, lib, ... }:

{
  targets.genericLinux.enable = true;
  
  home.packages = with pkgs; [
    shared-mime-info
    vlc
    spotify
  ];

  xdg = {
      enable = true;
      mime.enable = true;
      systemDirs.data = [ "${config.home.homeDirectory}/.nix-profile/share/applications" ];
  };
}
