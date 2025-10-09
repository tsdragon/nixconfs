{ config, pkgs, lib, ... }:
{
  # General-purpose low-latency PipeWire tuning that keeps several common rates available.
  services.pipewire.extraConfig.pipewire."10-desktop-audio" = {
    "context.properties" = {
      "default.clock.rate" = 96000;
      "default.clock.allowed-rates" = [ 32000 44100 48000 88200 96000 ];
      "default.clock.quantum" = 64;
      "default.clock.min-quantum" = 64;
      "default.clock.max-quantum" = 256;
    };

    context.modules = [
      {
        name = "libpipewire-module-protocol-pulse";
        args = {
          pulse.min.req = "64/48000";
          pulse.default.req = "128/48000";
          pulse.max.req = "256/48000";
          pulse.min.quantum = "64/48000";
          pulse.max.quantum = "256/48000";
        };
      }
    ];
    stream.properties = {
      node.latency = "64/48000";
      resample.quality = 10;
    };
  };
}
