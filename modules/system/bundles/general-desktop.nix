{
  config,
  pkgs,
  lib,
  ...
}: {
  hardware.bluetooth.enable = true;

  # WORKAROUND(2026-06-10): Provide /bin/sh for non-Nix-aware software that
  # assumes an FHS filesystem.
  environment.binsh = "${pkgs.bashInteractive}/bin/bash";

  # WORKAROUND(2026-06-10): VS Code downloads prebuilt server binaries that
  # require an FHS-like dynamic loader. Re-test if VS Code gains native NixOS
  # server support.
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
    wantedBy = ["default.target"];
    after = ["network-online.target"];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.vscode}/bin/code tunnel --name tal-nixos --accept-server-license-terms";
      Restart = "always";
      RestartSec = 10;

      # WORKAROUND(2026-06-10): The downloaded VS Code server invokes `env sh`;
      # keep /bin visible until the server no longer assumes an FHS layout.
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
      monospace = ["JetBrainsMono Nerd Font Mono"];
    };
  };
}
