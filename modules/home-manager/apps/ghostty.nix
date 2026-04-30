{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      font-family = "JetBrainsMono Nerd Font";
      font-size = 10;
      theme = "GruvboxMaterialDarkHard";
    };

    themes.GruvboxMaterialDarkHard = {
      background = "#1d2021";
      foreground = "#d4be98";
      cursor-color = "#a89984";
      cursor-text = "#1d2021";
      selection-background = "#d4be98";
      selection-foreground = "#1d2021";
      palette = [
        "0=#665c54"
        "1=#ea6962"
        "2=#a9b665"
        "3=#e78a4e"
        "4=#7daea3"
        "5=#d3869b"
        "6=#89b482"
        "7=#d4be98"
        "8=#928374"
        "9=#ea6962"
        "10=#a9b665"
        "11=#d8a657"
        "12=#7daea3"
        "13=#d3869b"
        "14=#89b482"
        "15=#d4be98"
      ];
    };
  };

  # Fix kde and dolphin terminal weirdness
  home.activation.kdeDefaultTerminal = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group General --key TerminalApplication ghostty
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group General --key TerminalService com.mitchellh.ghostty.desktop
  '';
}
