{ config, pkgs, lib, ... }:

{
  imports = [
    # VS Code
    (fetchTarball {
      url = "https://github.com/nix-community/nixos-vscode-server/tarball/8b6db451de46ecf9b4ab3d01ef76e59957ff549f";
      sha256 = "09j4kvsxw1d5dvnhbsgih0icbrxqv90nzf0b589rb5z6gnzwjnqf";
    })
  ];

  hardware.bluetooth.enable = true;

  # Enable VS Code and Server
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
    ubuntu_font_family
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
