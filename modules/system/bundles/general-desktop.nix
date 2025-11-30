{ config, pkgs, lib, ... }:

{
  hardware.bluetooth.enable = true;

  services.vscode-server.enable = true;

  environment.systemPackages = with pkgs; [
    #vscode
    kitty
    home-manager
    #bluez
    #micro
    #foot
  ];

  programs = {
    firefox.enable = true;
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  fonts.packages = with pkgs; [
    corefonts
    ubuntu-classic
  ] ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues nerd-fonts);

  fonts.enableDefaultPackages = true;
  fonts.fontconfig = {
    defaultFonts = {
      monospace = ["JetBrainsMono Nerd Font Mono"];
      #sansSerif = ["JetBrainsMono Nerd Font"];
      #serif = ["JetBrainsMono Nerd Font"];
    };
  };
}
