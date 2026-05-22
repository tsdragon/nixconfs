{pkgs, ...}: {
  services.flatpak.packages = [
    rec {
      appId = "io.github.block.Goose";
      sha256 = "1jgpj8f4sbbdha81gpy26xkxjrcvf4fp2pq7c22kkkq147s35bb1";
      bundle = "${pkgs.fetchurl {
        url = "https://github.com/aaif-goose/goose/releases/download/v1.34.1/io.github.block.Goose_stable_x86_64.flatpak";
        inherit sha256;
      }}";
    }
  ];

  services.flatpak.overrides.settings."io.github.block.Goose".Context.filesystems = [
    "/home/tal/Documents/sanctuary"
    "/home/tal/.config/nixconfs"
  ];
}
