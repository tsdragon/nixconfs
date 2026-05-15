{
  pkgs,
  lib,
  ...
}: let
  vscodeDisableUpdateChecks = pkgs.writeShellApplication {
    name = "vscode-disable-update-checks";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      perl
    ];
    text = ''
      set -euo pipefail

      ensure_setting() {
        settings_path="$1"
        mkdir -p "$(dirname "$settings_path")"

        if [ ! -e "$settings_path" ] || [ ! -s "$settings_path" ]; then
          printf '{\n  "update.mode": "none"\n}\n' > "$settings_path"
          return
        fi

        if grep -Eq '^[[:space:]]*"update\.mode"[[:space:]]*:[[:space:]]*"none"[[:space:]]*,?[[:space:]]*(//.*)?$' "$settings_path"; then
          return
        fi

        if grep -Eq '^[[:space:]]*"update\.mode"[[:space:]]*:' "$settings_path"; then
          perl -0pi -e 's/^([ \t]*)"update\.mode"[ \t]*:[ \t]*"[^"]*"([ \t]*,?)([ \t]*(?:\/\/[^\n]*)?\n)/$1"update.mode": "none"$2$3/m' "$settings_path"
          return
        fi

        perl -0pi -e 'if (!s/\{\s*\}/\{\n  "update.mode": "none"\n\}/s) { s/\{/\{\n  "update.mode": "none",\n/s }' "$settings_path"
      }

      config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"

      ensure_setting "$config_home/Code/User/settings.json"

      for settings_path in \
        "$config_home/Code - Insiders/User/settings.json" \
        "$config_home/Code - OSS/User/settings.json" \
        "$config_home/VSCodium/User/settings.json" \
        "$HOME/.var/app/com.visualstudio.code/config/Code/User/settings.json"
      do
        if [ -e "$settings_path" ]; then
          ensure_setting "$settings_path"
        fi
      done
    '';
  };
in {
  home.packages = [
    pkgs.vscode
    vscodeDisableUpdateChecks
  ];

  # Mutate the user-owned VS Code settings file without making Home Manager own it.
  home.activation.vscodeDisableUpdateChecks = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${vscodeDisableUpdateChecks}/bin/vscode-disable-update-checks
  '';
}
