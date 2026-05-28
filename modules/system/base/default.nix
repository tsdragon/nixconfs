{
  config,
  pkgs,
  ...
}: {
  nix.settings = {
    experimental-features = "nix-command flakes";
    download-buffer-size = 524288000;
  };

  nix.gc = {
    automatic = true;
    randomizedDelaySec = "14m";
    options = "--delete-older-than 10d";
  };

  boot.supportedFilesystems = ["ntfs"];

  time.timeZone = "America/Edmonton";
  i18n.defaultLocale = "en_CA.UTF-8";

  networking.networkmanager.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    wget
    tree
    nil
    less
    tldr
    exfatprogs
    sops
    nfs-utils
    p7zip
    unrar
    bc
    aria2
  ];

  programs = {
    zsh.enable = true;
    git.enable = true;
    screen.enable = true;
    bat.enable = true;
    zoxide.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
    gvfs = {
      enable = true;
    };
    aria2 = {
      enable = true;
      rpcSecretFile = "/var/lib/aria2/rpc-secret";
      serviceUMask = "0002";
    };
  };

  system.activationScripts.aria2RpcSecret.text = ''
    ${pkgs.coreutils}/bin/install -d -m 0750 -o root -g ${toString config.ids.gids.aria2} /var/lib/aria2
    if [ ! -s /var/lib/aria2/rpc-secret ]; then
      ${pkgs.openssl}/bin/openssl rand -base64 48 > /var/lib/aria2/rpc-secret
    fi
    ${pkgs.coreutils}/bin/chown root:${toString config.ids.gids.aria2} /var/lib/aria2/rpc-secret
    ${pkgs.coreutils}/bin/chmod 0640 /var/lib/aria2/rpc-secret
  '';
}
