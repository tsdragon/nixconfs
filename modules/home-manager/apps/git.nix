{ pkgs, inputs, config, lib, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = config.identity.name;
        email = config.identity.git_email;
      };
      # Keep default merge workflow for `git pull
      pull.rebase = false;
    };
  };
}
