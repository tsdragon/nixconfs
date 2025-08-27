(final: prev: {
  handbrake = prev.handbrake.overrideAttrs (old: {
    configureFlags = (old.configureFlags or []) ++ [ "--enable-svt-av1" ];
    buildInputs   = old.buildInputs ++ [ prev.svt-av1 ];
  });
})
