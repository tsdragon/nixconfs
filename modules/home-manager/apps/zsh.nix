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
      dotDir = "${config.home.homeDirectory}/.config/zsh";

      history  = {
        append = true;
        size = 100000;
        save = 100000;
        extended = true;
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

      completionInit = ''
        autoload -U compinit
        zmodload zsh/complist
        zstyle ':completion:*' menu select
        zstyle ':completion::complete:*' gain-privileges 1

        mkdir -p ${config.xdg.cacheHome}/zsh
        compinit -d ${config.xdg.cacheHome}/zsh/.zcompdump
        _comp_options+=(globdots)
      '';

      initContent = ''
        setopt INC_APPEND_HISTORY
        setopt HIST_FIND_NO_DUPS

        for rc in shortcutrc aliasrc zshnameddirrc; do
          candidate="''${XDG_CONFIG_HOME:-$HOME/.config}/shell/$rc"
          [[ -f "$candidate" ]] && source "$candidate"
        done

        typeset -g -A key

        key[Home]="''${terminfo[khome]}"
        key[End]="''${terminfo[kend]}"
        key[Insert]="''${terminfo[kich1]}"
        key[Backspace]="''${terminfo[kbs]}"
        key[Delete]="''${terminfo[kdch1]}"
        key[Up]="''${terminfo[kcuu1]}"
        key[Down]="''${terminfo[kcud1]}"
        key[Left]="''${terminfo[kcub1]}"
        key[Right]="''${terminfo[kcuf1]}"
        key[PageUp]="''${terminfo[kpp]}"
        key[PageDown]="''${terminfo[knp]}"
        key[Shift-Tab]="''${terminfo[kcbt]}"

        [[ -n "''${key[Home]}"      ]] && bindkey -- "''${key[Home]}"       beginning-of-line
        [[ -n "''${key[End]}"       ]] && bindkey -- "''${key[End]}"        end-of-line
        [[ -n "''${key[Insert]}"    ]] && bindkey -- "''${key[Insert]}"     overwrite-mode
        [[ -n "''${key[Backspace]}" ]] && bindkey -- "''${key[Backspace]}"  backward-delete-char
        [[ -n "''${key[Delete]}"    ]] && bindkey -- "''${key[Delete]}"     delete-char
        [[ -n "''${key[Up]}"        ]] && bindkey -- "''${key[Up]}"         up-line-or-history
        [[ -n "''${key[Down]}"      ]] && bindkey -- "''${key[Down]}"       down-line-or-history
        [[ -n "''${key[Left]}"      ]] && bindkey -- "''${key[Left]}"       backward-char
        [[ -n "''${key[Right]}"     ]] && bindkey -- "''${key[Right]}"      forward-char
        [[ -n "''${key[PageUp]}"    ]] && bindkey -- "''${key[PageUp]}"     beginning-of-buffer-or-history
        [[ -n "''${key[PageDown]}"  ]] && bindkey -- "''${key[PageDown]}"   end-of-buffer-or-history
        [[ -n "''${key[Shift-Tab]}" ]] && bindkey -- "''${key[Shift-Tab]}"  reverse-menu-complete

        if (( ''${+terminfo[smkx]} && ''${+terminfo[rmkx]} )); then
          autoload -Uz add-zle-hook-widget
          function zle_application_mode_start { echoti smkx }
          function zle_application_mode_stop { echoti rmkx }
          add-zle-hook-widget -Uz zle-line-init zle_application_mode_start
          add-zle-hook-widget -Uz zle-line-finish zle_application_mode_stop
        fi

        autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
        zle -N up-line-or-beginning-search
        zle -N down-line-or-beginning-search

        [[ -n "''${key[Up]}"   ]] && bindkey -- "''${key[Up]}"   up-line-or-beginning-search
        [[ -n "''${key[Down]}" ]] && bindkey -- "''${key[Down]}" down-line-or-beginning-search

        fastfetch
        eval "$(starship init zsh)"
        eval "$(zoxide init zsh)"
      '';
    };
  };  
}
