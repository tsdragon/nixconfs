{pkgs, ...}: {
  programs = {
    gamemode = {
      enable = true;
      settings.general.renice = 10;
    };
    steam.enable = true;
  };

  users.users.tal.extraGroups = ["gamemode"];

  environment.systemPackages = [
    pkgs.r2modman
  ];
}
