{ pkgs, ... }:

{
  security.polkit.enable = true;

  virtualisation = {
    libvirtd = {
      enable = true;
      dbus.enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true;
      };
    };

    spiceUSBRedirection.enable = true;
  };

  programs.virt-manager.enable = true;

  services.cockpit = {
    enable = true;
    openFirewall = true;
    plugins = with pkgs; [ cockpit-machines ];
  };
}
