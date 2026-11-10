{
  pkgs,
  pkgsUnstable,
  ...
}: {
  programs = {
    gamemode = {
      enable = true;
      settings.general.renice = 10;
    };
    steam.enable = true;
  };

  users.users.tal.extraGroups = ["gamemode"];

  environment.systemPackages = [
    # UMU 1.4.0 fails Steam Runtime 4 checksum validation against the moving URL.
    (pkgs.faugus-launcher.override {umu-launcher = pkgsUnstable.umu-launcher;})
    pkgs.r2modman
  ];
}
