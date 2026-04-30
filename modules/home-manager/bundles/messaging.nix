{
  pkgs,
  pkgsUnstable,
  ...
}: {
  home.packages = [
    # Stable is missing libzip include, using unstable for now.
    pkgsUnstable.telegram-desktop
    pkgs.discord
  ];
}
