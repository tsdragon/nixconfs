# Deprecated/Unused
{ config, pkgs, lib, inputs, ... }:

{

  programs.thunderbird = {
    enable = true;
    profiles = {
      ${config.home.username} = {
        isDefault = true;
      };
    };
  };

  accounts.email.accounts = {
    "protonmail" = {
      address = config.identity.email;
      userName = config.identity.email; # Used for both IMAP/SMTP login by HM module
      realName = config.identity.name;
      primary = true;

      # Define password command at the account level
      passwordCommand = "${pkgs.coreutils}/bin/cat ${config.sops.secrets."protonmail-bridge-password".path}";

      imap = {
        host = "127.0.0.1";
        port = 1143;
        tls = {
          enable = true;
          useStartTls = true;
        };
        # passwordCommand removed from here
      };

      smtp = {
        host = "127.0.0.1";
        port = 1025;
        tls = {
          enable = true;
          useStartTls = true;
        };
        # passwordCommand removed from here
      };

      thunderbird = {
        enable = true;
        profiles = [ config.home.username ];
      };
    };
  };
}
