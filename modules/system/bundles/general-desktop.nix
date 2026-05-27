{
  config,
  pkgs,
  lib,
  ...
}: {
  hardware.bluetooth.enable = true;

  # Clean NixOS fix for software that expects /bin/sh.
  environment.binsh = "${pkgs.bashInteractive}/bin/bash";

  # VS Code server/tunnel compatibility on NixOS.
  # VS Code downloads prebuilt server binaries, and nix-ld makes those run on NixOS.
  programs.nix-ld.enable = true;

  services.vscode-server = {
    enable = true;
    installPath = [
      "$HOME/.vscode-server"
      "$HOME/.vscode"
      "$HOME/.vscode/cli/servers"
      "$HOME/.vscode-server/cli/servers"
    ];
  };

  # Declarative VS Code tunnel service for your user.
  # Replace "tal-nixos" if you want a different tunnel name.
  systemd.user.services.vscode-tunnel = {
    description = "VS Code Tunnel";
    wantedBy = [ "default.target" ];
    after = [ "network-online.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.vscode}/bin/code tunnel --name tal-nixos --accept-server-license-terms";
      Restart = "always";
      RestartSec = 10;

      # Make sure `env sh` works inside the service environment.
      Environment = "PATH=/run/current-system/sw/bin:/bin";
    };
  };

  environment.systemPackages = with pkgs; [
    vscode
    bashInteractive
    coreutils
    wget
    curl
    gnutar
    gzip

    kitty
    home-manager
  ];

  programs = {
    firefox.enable = true;
  };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  fonts.packages = with pkgs;
    [
      corefonts
      ubuntu-classic
    ]
    ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues nerd-fonts);

  fonts.enableDefaultPackages = true;
  fonts.fontconfig = {
    defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font Mono" ];
    };
  };
}
