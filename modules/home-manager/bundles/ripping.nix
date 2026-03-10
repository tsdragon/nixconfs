{ config, pkgs, lib, inputs, ... }:

let
  opusToolsCompat = pkgs.opus-tools.overrideAttrs (old: {
    # libopus 1.6+ exports opus_check_* while opus-tools 0.2 expects __opus_check_*.
    NIX_CFLAGS_COMPILE =
      (old.NIX_CFLAGS_COMPILE or "")
      + " -D__opus_check_int=opus_check_int -D__opus_check_int_ptr=opus_check_int_ptr";
  });

  flac2allCompat = pkgs.flac2all.override {
    "opus-tools" = opusToolsCompat;
  };
in

{
  home.packages = with pkgs; [
    # EAC requires a full WoW Wine build; plain `wine` can miss functions on startup.
    (exactaudiocopy.override {
      wine = wineWow64Packages.stable;
      use64 = true;
    })
    flac
    lame
    mktorrent
    flac2allCompat
  ];
}
