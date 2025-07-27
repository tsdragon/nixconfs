# This module is used to manage secrets with sops at the home level.
# System level config is at modules/system/base/sops.nix
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  sops.defaultSopsFile = ../../../secrets/secrets.yaml; # Or .json
  sops.defaultSopsFormat = "yaml";
  
  # Decrypt using host SSH keys
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.secrets = {
    "email" = {};
    "git_email" = {};
  };

}