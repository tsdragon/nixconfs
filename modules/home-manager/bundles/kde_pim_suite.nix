# Deprecated/Unused
{ config, pkgs, lib, ... }:

{
  # Add the KDE PIM application packages for your user
  home.packages = with pkgs.kdePackages; [
    # The main Kontact suite integrator (pulls in KMail, KOrganizer, etc.)
    kontact
    kmail-account-wizard

    # Optional but recommended: provides various plugins and integration features
    kdepim-addons

    # Optional: Add specific backend support if needed
    # For Exchange Web Services (EWS):
    # akonadi-ews
    # For Google integration (may still require manual setup within Kontact):
    # akonadi-googledata
  ];

  # You could potentially add specific user-level configurations here later
  # if needed, though much of the setup happens within Kontact itself.
}
