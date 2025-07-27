{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/home-manager/apps/zsh.nix
    ../../modules/home-manager/apps/firefox.nix
  ];

  nixpkgs.config.allowUnfree = true;

  home = {
    username = "tal";
    homeDirectory = "/home/tal";
  };

  home.packages = with pkgs; [
    orca-slicer
  ];

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      userName = "Tal";
      userEmail = "tal@steakdrake.co";
      settings = {
      # This ensures that "git pull" uses merges (the default behavior)
        "pull.rebase" = "false";

      # Optional: Git’s behavior regarding fast-forward merges can also be set:
      # "pull.ff" = "true";  # Fast-forward if possible, otherwise merge
      # "pull.ff" = "false"; # Always create a merge commit, even if fast-forward is possible
      };
    };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  home.stateVersion = "24.05"; # Match your NixOS version
}
