{ config, pkgs, lib, ... }:

{
  options.identity = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "User's full real name.";
    };
    email = lib.mkOption {
      type = lib.types.str;
      description = "User's primary email address.";
    };
    git_email = lib.mkOption {
      type = lib.types.str;
      description = "User's Git email.";
    };
    # Add more if needed (e.g., work email, other usernames, etc.)
  };

  config = {
    identity = {
      name = "Tal";
      # minor obfuscation to avoid email scraping when uploading configs to repos
      email = builtins.replaceStrings ["_AT_" "_DOT_"] ["@" "."] "talbull_AT_protonmail_DOT_ch";
      git_email = builtins.replaceStrings ["_AT_" "_DOT_"] ["@" "."] "tal_AT_steakdrake_DOT_co";
    };
  };
}