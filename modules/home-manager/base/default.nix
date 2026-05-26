{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../apps/vscode.nix
  ];

  home.packages = with pkgs; [
    shared-mime-info
    vlc
    tidal-hifi
  ];

  xdg = {
    enable = true;
    mime.enable = true;
    systemDirs.data = ["${config.home.homeDirectory}/.nix-profile/share/applications"];

    mimeApps = {
      enable = true;
      associations.added = {
        "application/x-shellscript" = "code.desktop";
        "text/plain" = "code.desktop";
        "text/x-nfo" = "code.desktop";
        "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
        "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
      };

      defaultApplications = {
        "application/x-shellscript" = "code.desktop";
        "text/plain" = "code.desktop";
        "text/x-nfo" = "code.desktop";
        "x-scheme-handler/obsidian" = "obsidian.desktop";
        "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
        "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
        "video/mp4" = "vlc.desktop";
        "video/x-m4v" = "vlc.desktop";
        "video/x-msvideo" = "vlc.desktop";
        "video/x-matroska" = "vlc.desktop";
        "video/webm" = "vlc.desktop";
        "video/ogg" = "vlc.desktop";
      };
    };
  };
}
