{ config, pkgs, lib, ... }:

{

  home.packages = with pkgs; [
    fastfetch
    zoxide
  ];

  programs = {
    starship = {
      enable = true;
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      defaultKeymap = "viins";
      dotDir = ".config/zsh";

      history  = {
        append = true;
        size = 100000;
        ignoreAllDups = true;
        ignoreSpace = true;
        share = true;
        ignorePatterns = [
          "ls"
          "ls *"
          "clear"
          "history"
          "exit"
          "reset"
          "rm *"
          "sudo rm *"
          "kill *"
        ];
      };

      shellAliases = {
        nrs = "sudo nixos-rebuild switch --flake ~/.config/nixconfs#$(hostname)";
        hms = "home-manager switch --flake ~/.config/nixconfs#$(whoami)@$(hostname)";
        full_upgrade = "nix flake update --flake ~/.config/nixconfs && nrs && hms";
        cat = "bat --paging=never";
        cd = "z";
        cp = "cp -iv";
        mv = "mv -iv";
        rm = "rm -vI";
        bc = "bc -l";
        ls = "ls -hN --color=auto --group-directories-first";
        grep = "grep --color=auto";
        diff = "diff --color=auto";
        ssh = "TERM=xterm-256color ssh";
      };

      sessionVariables = {
        XDG_CONFIG_HOME = "$HOME/.config";
        XDG_CACHE_HOME  = "$HOME/.cache";
        XDG_DATA_HOME   = "$HOME/.local/share";
      };

      initContent = ''
        fastfetch
        eval "$(starship init zsh)"
        eval "$(zoxide init zsh)"
      '';
    };
  };  
}
