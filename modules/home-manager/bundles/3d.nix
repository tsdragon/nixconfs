{
  config,
  pkgs,
  lib,
  ...
}:
# WORKAROUND(2026-06-10): LycheeSlicer's desktop entry expects a lowercase
# executable name. Remove this alias when the packaged entry is corrected.
let
  lycheeWrapper = pkgs.writeShellScriptBin "lychee" ''
    exec LycheeSlicer "$@"
  '';
in {
  imports = [
    ../apps/orca-slicer.nix
  ];

  home.packages = with pkgs; [
    blender
    openscad
    unityhub
    lycheeslicer
    lycheeWrapper
  ];
}
