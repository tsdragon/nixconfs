{ pkgs, inputs, config, lib, ... }:
let
  system = pkgs.stdenv.system;
  # Or use config.nixpkgs.system, or any variable that indicates your system (x86_64-linux, aarch64-linux, etc.)
in {
  home.packages = [
    pkgs.orca-slicer
    inputs.nix-alien.packages.${system}.nix-alien
  ];
  home.file.".local/share/applications/orca-slicer.desktop".text = ''
    [Desktop Entry]
    Name=Orca Slicer (nix-alien)
    Exec=sh -c 'nix-alien "$(which orca-slicer)"'
    Icon=orca-slicer
    Type=Application
    Terminal=false
    Categories=Graphics;
  '';
}