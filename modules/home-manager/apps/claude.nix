{pkgs, ...}: let
  jsonFormat = pkgs.formats.json {};

  allowedDirectories = [
    "/home/tal/.config/nixconfs"
    "/home/tal/Documents/sanctuary"
  ];

  claudeMcpServers = {
    Filesystem = {
      command = "${pkgs.nodejs}/bin/npx";
      args = ["-y" "@modelcontextprotocol/server-filesystem"] ++ allowedDirectories;
    };
  };
in {
  programs.mcp = {
    enable = true;
    servers = claudeMcpServers;
  };

  home.packages = [
    pkgs.nodejs
  ];

  xdg.configFile."Claude/claude_desktop_config.json".source = jsonFormat.generate "claude_desktop_config.json" {
    mcpServers = claudeMcpServers;
  };
}
