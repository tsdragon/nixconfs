(final: prev: {
  roon-bridge = prev.roon-bridge.overrideAttrs (_old: {
    version = "2.60-1501";
    src = prev.fetchurl {
      url = "https://download.roonlabs.com/builds/RoonBridge_linuxx64.tar.bz2";
      hash = "sha256-7flBDwWeHU0VPDsgV7ut+nwRv3PoJ4KxbFOXcAXE1No=";
    };
  });
})
