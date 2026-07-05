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

  # WORKAROUND(2026-06-10): The SDDM login greeter can race the desktop
  # PipeWire session for USB audio devices. Re-test after login manager or
  # PipeWire updates.
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

  # Keep desktop/voice capture on the WebRTC-friendly default while still
  # allowing music/audio-production clients to request higher rates.
  services.pipewire.extraConfig.pipewire."10-desktop-audio" = {
    "context.properties" = {
      "default.clock.rate" = 48000;
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
