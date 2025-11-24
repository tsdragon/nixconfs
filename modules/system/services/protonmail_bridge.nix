# Deprecated/Unused
{ config, pkgs, ... }:

{
  services.protonmail-bridge = {
    enable = true;
    package = pkgs.protonmail-bridge;
  };

  # ProtonMail Bridge relies on a password/keyring manager.
  # Ensure one is available and configured for your user session.
  # Common options include gnome-keyring or keepassxc.
  # Example using gnome-keyring (often included with Gnome DE):
  #services.gnome.gnome-keyring.enable = true;
  # Or configure another secret service provider if needed.
}
