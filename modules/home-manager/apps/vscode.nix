{
  pkgs,
  pkgsUnstable,
  lib,
  ...
}: let
  jsoncParser = pkgs.fetchzip {
    url = "https://registry.npmjs.org/jsonc-parser/-/jsonc-parser-3.3.1.tgz";
    hash = "sha256-eZb4Epz0UsTTaSstqBl46Sy/KRyKaJ+vBUJ92/6wsZY=";
  };
  vscodeDisableUpdateChecks = pkgs.writeShellApplication {
    name = "vscode-disable-update-checks";
    runtimeInputs = [pkgs.nodejs];
    text = ''
      export JSONC_PARSER=${jsoncParser}/lib/umd/main.js
      exec node ${./vscode-settings.cjs}
    '';
  };
in {
  home.packages = [pkgsUnstable.vscode vscodeDisableUpdateChecks];

  # WORKAROUND(2026-11-13): Suppress startup update prompts while keeping the
  # settings file writable by VS Code (including column-selection settings).
  home.activation.vscodeDisableUpdateChecks = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run ${vscodeDisableUpdateChecks}/bin/vscode-disable-update-checks
  '';
}
