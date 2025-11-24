# Deprecated/Unused
{ config, pkgs, ... }:

{
  # Even though GDM runs in Wayland mode, we still need the xserver module enabled
  # because GDM is managed by it.
  services.xserver = {
    enable = true;

    displayManager.gdm = {
      enable = true;
      wayland = true;
    };

    desktopManager.gnome.enable = true;
  };
}
