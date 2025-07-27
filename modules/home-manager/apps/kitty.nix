{ config, pkgs, lib, ... }:

{
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 10;
    };
    extraConfig = "cursor_trail 1";
    shellIntegration.enableZshIntegration = true;
    themeFile = "GruvboxMaterialDarkHard";
    # See all available kitty themes at: https://github.com/kovidgoyal/kitty-themes/tree/master/themes
  };
}
