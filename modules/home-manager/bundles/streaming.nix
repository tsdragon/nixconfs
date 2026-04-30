{pkgs, ...}: {
  # OBS Studio with plugins
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-backgroundremoval
      obs-pipewire-audio-capture
      obs-composite-blur
      obs-shaderfilter
      obs-scale-to-sound
      obs-move-transition
      obs-gradient-source
      obs-replay-source
      obs-source-clone
      obs-3d-effect
      obs-livesplit-one
      waveform
      obs-gstreamer
      obs-vaapi
      obs-vkcapture
    ];
  };
}
