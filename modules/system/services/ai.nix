{pkgsUnstable, ...}: let
  openWebuiImage = "ghcr.io/open-webui/open-webui:v0.8.12";
in {
  services.ollama = {
    enable = true;
    package = pkgsUnstable.ollama-cuda;
  };

  # Persist Open WebUI state outside the container filesystem.
  systemd.tmpfiles.rules = [
    "d /var/lib/open-webui 0750 root root -"
  ];

  virtualisation.oci-containers.backend = "podman";

  virtualisation.oci-containers.containers.open-webui = {
    image = openWebuiImage;
    environment = {
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
    };
    volumes = [
      "/var/lib/open-webui:/app/backend/data"
    ];
    extraOptions = [
      "--network=host"
    ];
  };
}
