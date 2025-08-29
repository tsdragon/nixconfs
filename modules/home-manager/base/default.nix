{ config, pkgs, lib, ... }:

{
  targets.genericLinux.enable = true;
  
  home.packages = with pkgs; [
    shared-mime-info
    vlc
    spotify
  ];

  programs.vscode = {
    enable = true;
    profiles.default.userSettings = {
      "update.mode" = "none";
    };
  };

  xdg = {
      enable = true;
      mime.enable = true;
      systemDirs.data = [ "${config.home.homeDirectory}/.nix-profile/share/applications" ];
  };

  # Manage mimeapps.list
  home.file.".config/mimeapps.list".text = ''
    [Added Associations]
    application/x-shellscript=code.desktop;
    text/plain=code.desktop;
    text/x-nfo=code.desktop;
    x-scheme-handler/tg=org.telegram.desktop.desktop;
    x-scheme-handler/tonsite=org.telegram.desktop.desktop;

    [Default Applications]
    application/x-shellscript=code.desktop;
    text/plain=code.desktop;
    text/x-nfo=code.desktop;
    x-scheme-handler/obsidian=obsidian.desktop;
    x-scheme-handler/tg=org.telegram.desktop.desktop;
    x-scheme-handler/tonsite=org.telegram.desktop.desktop;
    video/mp4=vlc.desktop;
    video/x-m4v=vlc.desktop;
    video/x-msvideo=vlc.desktop;
    video/x-matroska=vlc.desktop;
    video/webm=vlc.desktop;
    video/ogg=vlc.desktop;
  '';
}
