
{ config, pkgs, inputs, ... }: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops.defaultSopsFile = ../../../secrets/secrets.yaml; # Or .json
  sops.defaultSopsFormat = "yaml";

  # Decrypt using host SSH keys
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # VERY IMPORTANT for Home Manager integration:
  # Ensure secrets provisioned for users are accessible before users are provisioned.
  #sops.secrets."placeholder-for-users" = {
  #   neededForUsers = true;
  #};

  sops.secrets = {
    "nas-password" = {};
  };

  sops.templates."cifs_creds" = {
    content = ''
      username=tal
      password=${config.sops.placeholder.nas-password}
    '';
  };
  
  # Ensure the 'keys' group exists if secrets use it (often the default)
  users.groups.keys = {};
}