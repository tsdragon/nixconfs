{
  config,
  pkgs,
  lib,
  ...
}: {
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

  # WORKAROUND(2026-06-10): KDE/Dolphin do not consistently discover Kitty as
  # the default terminal. Re-test after Plasma or Kitty desktop entry updates.
  home.activation.kdeDefaultTerminal = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group General --key TerminalApplication kitty
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group General --key TerminalService kitty.desktop
  '';
}
