{
  config,
  inputs,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}: let
  sanctuaryPath = "/home/tal/Documents/sanctuary";
  mcpvault = pkgs.writeShellApplication {
    name = "mcpvault";
    runtimeInputs = [
      pkgs.bash
      pkgsUnstable.nodejs_24
    ];
    text = ''
      export NPM_CONFIG_CACHE="''${NPM_CONFIG_CACHE:-/var/lib/librechat/npm-cache}"
      export HOME="''${HOME:-/var/lib/librechat}"
      exec npx -y @bitbonsai/mcpvault@0.11.0 "$@"
    '';
  };
in {
  disabledModules = [
    "services/web-apps/librechat.nix"
  ];

  imports = [
    "${inputs.nixpkgs-unstable}/nixos/modules/services/web-apps/librechat.nix"
  ];

  sops.secrets = {
    "librechat-creds-key" = {};
    "librechat-creds-iv" = {};
    "librechat-jwt-secret" = {};
    "librechat-jwt-refresh-secret" = {};
    "librechat-openrouter-key" = {};
  };

  services.flatpak.packages = [
    rec {
      appId = "io.github.block.Goose";
      sha256 = "1jgpj8f4sbbdha81gpy26xkxjrcvf4fp2pq7c22kkkq147s35bb1";
      bundle = "${pkgs.fetchurl {
        url = "https://github.com/aaif-goose/goose/releases/download/v1.34.1/io.github.block.Goose_stable_x86_64.flatpak";
        inherit sha256;
      }}";
    }
  ];

  services.flatpak.overrides.settings."io.github.block.Goose".Context.filesystems = [
    "/home/tal/Documents/sanctuary"
    "/home/tal/.config/nixconfs"
  ];

  services.librechat = {
    enable = true;
    package = pkgsUnstable.librechat;
    enableLocalDB = true;

    env = {
      HOST = "127.0.0.1";
      PORT = 3080;
      ALLOW_REGISTRATION = true;
    };

    credentials = {
      CREDS_KEY = config.sops.secrets."librechat-creds-key".path;
      CREDS_IV = config.sops.secrets."librechat-creds-iv".path;
      JWT_SECRET = config.sops.secrets."librechat-jwt-secret".path;
      JWT_REFRESH_SECRET = config.sops.secrets."librechat-jwt-refresh-secret".path;
      OPENROUTER_KEY = config.sops.secrets."librechat-openrouter-key".path;
    };

    settings = {
      version = "1.2.1";

      endpoints.custom = [
        {
          name = "OpenRouter";
          apiKey = "\${OPENROUTER_KEY}";
          baseURL = "https://openrouter.ai/api/v1";
          models = {
            default = ["openrouter/auto"];
            fetch = true;
          };
          titleConvo = true;
          titleModule = "openrouter/auto";
          dropParams = ["stop"];
          modelDisplayLabel = "OpenRouter";
        }
      ];

      mcpServers = {
        sanctuary-filesystem = {
          type = "stdio";
          title = "Sanctuary Filesystem";
          description = "Read and write files under the sanctuary directory.";
          command = lib.getExe pkgsUnstable.mcp-server-filesystem;
          args = [sanctuaryPath];
          serverInstructions = "Only access files under ${sanctuaryPath}.";
        };

        sanctuary-vault = {
          type = "stdio";
          title = "Sanctuary MCPVault";
          description = "Obsidian-style note tools scoped to the sanctuary directory.";
          command = lib.getExe mcpvault;
          args = [sanctuaryPath];
          env = {
            HOME = "/var/lib/librechat";
            NPM_CONFIG_CACHE = "/var/lib/librechat/npm-cache";
          };
          serverInstructions = "Only access notes and files under ${sanctuaryPath}.";
        };
      };
    };
  };

  services.mongodb.package = pkgs.mongodb-ce;

  systemd.services.librechat = {
    after = ["mongodb.service"];
    wants = ["mongodb.service"];

    serviceConfig = {
      ProtectHome = lib.mkForce "tmpfs";
      BindPaths = [sanctuaryPath];
      ReadWritePaths = [sanctuaryPath];
      UMask = lib.mkForce "0002";
    };
  };

  systemd.tmpfiles.rules = [
    "d ${sanctuaryPath} 2775 tal users - -"
    "d /var/lib/librechat/logs 0750 librechat librechat - -"
    "d /var/lib/librechat/uploads 0750 librechat librechat - -"
    "d /var/lib/librechat/images 0750 librechat librechat - -"
    "d /var/lib/librechat/npm-cache 0750 librechat librechat - -"
    "Z /var/lib/librechat/logs 0750 librechat librechat - -"
    "Z /var/lib/librechat/uploads 0750 librechat librechat - -"
    "Z /var/lib/librechat/images 0750 librechat librechat - -"
    "A+ ${sanctuaryPath} - - - - u:librechat:rwX,g::rwX,m::rwX,d:u:librechat:rwX,d:g::rwX,d:m::rwX"
  ];
}
