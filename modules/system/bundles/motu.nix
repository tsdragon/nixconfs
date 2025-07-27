{ config, pkgs, lib, ... }:
{
  services.pipewire.extraConfig.pipewire."10-motu-settings" = {
    "context.properties" = {
      # Force 48k only
      "default.clock.rate" = 48000;
      "default.clock.allowed-rates" = [ 48000 ];
      "default.clock.quantum" = 512;
      "default.clock.min-quantum" = 512;
      "default.clock.max-quantum" = 512;
    };

    context.modules = [
      {
        name = "libpipewire-module-protocol-pulse";
        args = {
          pulse.min.req = "512/48000";
          pulse.default.req = "512/48000";
          pulse.max.req = "512/48000";
          pulse.min.quantum = "512/48000";
          pulse.max.quantum = "512/48000";
        };
      }
    ];
    stream.properties = {
      node.latency = "512/48000";
      resample.quality = 1;
    };
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="07fd", ATTR{idProduct}=="0005", TEST=="power/control", ATTR{power/control}="on"
  '';
}
