{ config, pkgs, lib, ... }:

{
services.udev.extraRules = ''
  # ODrive Robotics udev rules
  SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="0d[0-9][0-9]", MODE="0666"
'';
}