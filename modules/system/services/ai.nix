{
  config,
  lib,
  pkgs,
  ...
}: let
  sanctuaryPath = "/home/tal/Documents/sanctuary";
  sttPython = pkgs.python3.withPackages (ps: [ps.pyyaml]);
  sanctuaryStt = pkgs.writeShellApplication {
    name = "sanctuary-stt";
    runtimeInputs = [sttPython pkgs.ffmpeg-headless];
    text = ''
      exec python3 ${./sanctuary-stt/server.py} "$@"
    '';
  };
  gooseVersion = "1.35.0";
  gooseHash = "sha256-AsxgV7zvtY3tQxAfezVLEh9JWcPw/HiidtQPYYK+x2A=";
  # WORKAROUND(2026-06-10): MCPVault is not packaged here, so run its pinned npm
  # release through npx. Replace this with a Nix package when one is available.
  mcpvault = pkgs.writeShellApplication {
    name = "mcpvault";
    runtimeInputs = [
      pkgs.bash
      pkgs.nodejs_24
    ];
    text = ''
      export NPM_CONFIG_CACHE="''${NPM_CONFIG_CACHE:-/var/lib/librechat/npm-cache}"
      export HOME="''${HOME:-/var/lib/librechat}"
      exec npx -y @bitbonsai/mcpvault@0.11.0 "$@"
    '';
  };
in {
  sops.secrets = {
    "librechat-creds-key".restartUnits = ["librechat.service"];
    "librechat-creds-iv".restartUnits = ["librechat.service"];
    "librechat-jwt-secret".restartUnits = ["librechat.service"];
    "librechat-jwt-refresh-secret".restartUnits = ["librechat.service"];
    "librechat-openrouter-key".restartUnits = ["librechat.service" "sanctuary-stt.service"];
  };

  services.flatpak.packages = [
    {
      appId = "io.github.block.Goose";
      sha256 = gooseHash;
      bundle = "${pkgs.fetchurl {
        url = "https://github.com/aaif-goose/goose/releases/download/v${gooseVersion}/io.github.block.Goose_stable_x86_64.flatpak";
        hash = gooseHash;
      }}";
    }
  ];

  services.flatpak.overrides.settings."io.github.block.Goose".Context.filesystems = [
    "/home/tal/Documents/sanctuary"
    "/home/tal/.config/nixconfs"
  ];

  services.librechat = {
    enable = true;
    enableLocalDB = true;
    openFirewall = false;
    # Stdio MCP servers inherit this identity when creating sanctuary files.
    user = "tal";
    group = "users";

    env = {
      HOST = "127.0.0.1";
      PORT = 3080;
      ALLOW_REGISTRATION = false;
      ALLOW_SOCIAL_REGISTRATION = false;
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

      speech = {
        stt.openai = {
          url = "http://127.0.0.1:3081/v1/audio/transcriptions";
          apiKey = "\${OPENROUTER_KEY}";
          model = "microsoft/mai-transcribe-2";
        };
        speechTab = {
          conversationMode = false;
          speechToText = {
            engineSTT = "openai";
            languageSTT = "English (US)";
            autoTranscribeAudio = false;
            autoSendText = -1;
          };
        };
      };

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
          command = lib.getExe pkgs.mcp-server-filesystem;
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
    after = ["mongodb.service" "sanctuary-stt.service"];
    wants = ["mongodb.service" "sanctuary-stt.service"];

    # WORKAROUND(2026-06-10): Override the module's home isolation and umask so
    # LibreChat can share the user-owned directories. Re-test if the
    # upstream module exposes supported options for bind paths and shared files.
    serviceConfig = {
      ProtectHome = lib.mkForce "tmpfs";
      BindPaths = [sanctuaryPath];
      ReadWritePaths = [sanctuaryPath];
      UMask = lib.mkForce "0002";
    };
  };

  systemd.services.sanctuary-stt = {
    description = "Sanctuary vocabulary for LibreChat transcription via OpenRouter";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    environment = {
      SANCTUARY_PATH = sanctuaryPath;
      STT_TERMS_FILE = "${./sanctuary-stt/terms.txt}";
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };
    serviceConfig = {
      ExecStart = lib.getExe sanctuaryStt;
      User = "tal";
      Group = "users";
      LoadCredential = "openrouter-key:${config.sops.secrets."librechat-openrouter-key".path}";
      Restart = "on-failure";
      RestartSec = 5;
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = "tmpfs";
      BindReadOnlyPaths = [sanctuaryPath];
      RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
      MemoryMax = "512M";
    };
  };

  systemd.tmpfiles.rules = [
    "d ${sanctuaryPath} 2775 tal users - -"
    "d /var/lib/librechat/logs 0750 tal users - -"
    "d /var/lib/librechat/uploads 0750 tal users - -"
    "d /var/lib/librechat/images 0750 tal users - -"
    "d /var/lib/librechat/npm-cache 0750 tal users - -"
    "Z /var/lib/librechat/logs 0750 tal users - -"
    "Z /var/lib/librechat/uploads 0750 tal users - -"
    "Z /var/lib/librechat/images 0750 tal users - -"
    "Z /var/lib/librechat/npm-cache - tal users - -"
  ];
}
