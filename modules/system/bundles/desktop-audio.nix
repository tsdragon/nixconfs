{
  config,
  pkgs,
  lib,
  ...
}: {
  boot = {
    kernelModules = ["snd-aloop"];
    extraModprobeConfig = ''
      options snd-aloop id=RoonPipeWire index=8 enable=1 pcm_substreams=1 pcm_notify=1
    '';
  };

  # Keep the login greeter from claiming audio devices before the desktop session.
  systemd.user = {
    services = {
      pipewire.unitConfig.ConditionUser = "!plasmalogin";
      pipewire-pulse.unitConfig.ConditionUser = "!plasmalogin";
      wireplumber.unitConfig.ConditionUser = "!plasmalogin";
    };

    sockets = {
      pipewire.unitConfig.ConditionUser = "!plasmalogin";
      pipewire-pulse.unitConfig.ConditionUser = "!plasmalogin";
    };
  };

  # General-purpose low-latency PipeWire tuning that keeps several common rates available.
  services.pipewire.extraConfig.pipewire."10-desktop-audio" = {
    "context.properties" = {
      "default.clock.rate" = 96000;
      "default.clock.allowed-rates" = [32000 44100 48000 88200 96000];
      "default.clock.quantum" = 128;
      "default.clock.min-quantum" = 64;
      "default.clock.max-quantum" = 256;
    };

    stream.properties = {
      resample.quality = 10;
    };
  };
}
