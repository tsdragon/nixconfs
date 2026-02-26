{ config, pkgs, lib, inputs, ... }:

let
  unstablePkgs = import inputs.nixpkgs-unstable {
    system = pkgs.system;
    config.allowUnfree = true;
  };
in {
  home.packages = with pkgs; [
    unstablePkgs.exactaudiocopy
    flac
    lame
    mktorrent
    flac2all
  ];
}
