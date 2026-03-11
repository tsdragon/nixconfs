{ pkgs, pkgsUnstable, ... }:

{
  security.polkit.enable = true;

  virtualisation = {
    libvirtd = {
      enable = true;
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
  };

  environment.systemPackages = [
    pkgsUnstable.cockpit-machines
    pkgs.libvirt-dbus
  ];

  users.users.libvirtdbus = {
    isSystemUser = true;
    group = "libvirtdbus";
    description = "Libvirt D-Bus bridge";
  };
  users.groups.libvirtdbus = {};

  systemd.packages = [ pkgs.libvirt-dbus ];
  services.dbus.packages = [ pkgs.libvirt-dbus ];
}
