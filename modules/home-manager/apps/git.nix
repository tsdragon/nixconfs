{ pkgs, inputs, config, lib, ... }:

{
  programs.git = {
    enable = true;
    userName = config.identity.name;
    userEmail = config.identity.git_email;
    extraConfig = {
    # This ensures that "git pull" uses merges (the default behavior)
      pull.rebase = false;

    # Optional: Git’s behavior regarding fast-forward merges can also be set:
    # "pull.ff" = "true";  # Fast-forward if possible, otherwise merge
    # "pull.ff" = "false"; # Always create a merge commit, even if fast-forward is possible
    };
  };
}
