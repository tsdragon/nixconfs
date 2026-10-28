{pkgs, ...}: {
  home.packages = with pkgs; [
    # WORKAROUND(2026-10-26): Cygwin 3.6.6 was removed from the upstream mirror.
    # Remove once nixpkgs updates Exact Audio Copy's runtime download.
    (exactaudiocopy.override {
      fetchurl = args:
        if pkgs.lib.hasSuffix "/cygwin-3.6.6-1-x86_64.tar.xz" args.url
        then
          pkgs.fetchurl {
            url = "https://cygwin.com/pub/cygwin/x86_64/release/cygwin/cygwin-3.6.12-1-x86_64.tar.xz";
            hash = "sha256-tRFXmfRtSxCGSq/3qKG14+exvOA3J8d0+U1njI3WknU=";
          }
        else pkgs.fetchurl args;
    })
    flac
    lame
    mktorrent
    flac2all
  ];
}
