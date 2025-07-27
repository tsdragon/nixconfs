{ config, lib, pkgs, ... }: {
  options.myNixOS.services.cockpit = {
    enable = lib.mkEnableOption "Enable Cockpit web console";
    port = lib.mkOption {
      type = lib.types.port;
      default = 9090;
      description = "Port for Cockpit web console";
    };
  };

  config = lib.mkIf config.myNixOS.services.cockpit.enable {
    services.cockpit = {
      enable = true;
      port = config.myNixOS.services.cockpit.port;
    };
    
    # Open firewall port
    networking.firewall.allowedTCPPorts = [ config.myNixOS.services.cockpit.port ];
  };
}
