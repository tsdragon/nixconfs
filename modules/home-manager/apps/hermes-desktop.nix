{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  userDataDir = "${config.xdg.configHome}/hermes-desktop";
  connections = pkgs.writeText "hermes-desktop-connections.json" (builtins.toJSON {
    version = 2;
    primary = "tal-server";
    launchMode = "primary";
    lastUsed = "tal-server";
    connections = [
      {
        id = "local";
        kind = "local";
        label = "Local";
      }
      {
        id = "tal-server";
        kind = "ssh";
        label = "Tal server";
        host = "192.168.1.247";
        user = "tal";
        remoteHermesPath = "/home/tal/.local/bin/hermes";
      }
    ];
  });
in {
  home.packages = [
    (inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.desktop.override {
      extraEnv.HERMES_DESKTOP_USER_DATA_DIR = userDataDir;
      extraRun = [
        ''export PATH="${lib.makeBinPath [pkgs.openssh pkgs.coreutils]}:$PATH"''
        # Seed writable state only once; Desktop stores SSH tokens and edits here.
        ''
          if [ ! -e ${lib.escapeShellArg "${userDataDir}/connections.json"} ]; then
            (umask 077
              mkdir -p ${lib.escapeShellArg userDataDir}
              install -m 600 ${connections} ${lib.escapeShellArg "${userDataDir}/connections.json"}
            )
          fi
        ''
      ];
    })
  ];
}
