{ config, pkgs, lib, ... }:
{
  services.pipewire.extraConfig.pipewire."10-motu-settings" = {
    "context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.allowed-rates" = [ 48000 ];
      "default.clock.quantum" = 128;
      "default.clock.min-quantum" = 128;
      "default.clock.max-quantum" = 128;
    };

    context.modules = [
      {
        name = "libpipewire-module-protocol-pulse";
        args = {
          pulse.min.req = "128/48000";
          pulse.default.req = "128/48000";
          pulse.max.req = "128/48000";
          pulse.min.quantum = "128/48000";
          pulse.max.quantum = "128/48000";
        };
      }
    ];
    stream.properties = {
      node.latency = "128/48000";
      resample.quality = 1;
    };
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="07fd", ATTR{idProduct}=="0005", TEST=="power/control", ATTR{power/control}="on"
  '';
}
