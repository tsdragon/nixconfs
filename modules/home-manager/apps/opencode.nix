{...}: {
  programs.opencode = {
    enable = true;
    context = ''
      # Global Instructions

      - Follow YAGNI: implement only what the current requirements need. Do not add speculative features, abstractions, or dependencies.
      - Follow KISS: prefer the simplest correct solution and small, focused changes. Follow existing project conventions and avoid unnecessary complexity.
      - Use Context7 proactively for up-to-date library and API documentation when writing code, answering API questions, or configuring dependencies, without waiting to be asked. Match the project's dependency versions when available. Resolve the library ID before querying its documentation unless the ID is already known. If Context7 is unavailable or lacks the needed documentation, use official documentation and state the limitation.
    '';
    settings = {
      # Updates are managed by the pinned Nix package, not OpenCode itself.
      autoupdate = false;
      share = "manual";
      provider.openrouter.models."qwen/qwen3.8-27b".options.provider.only = ["alibaba" "novita"];
      agent.qwen-coder = {
        description = "Implements delegated coding changes and executes explicitly scoped shell tasks using Qwen. Use for well-defined implementation, testing, and command execution tasks.";
        mode = "subagent";
        model = "openrouter/qwen/qwen3.8-27b";
        prompt = ''
          Complete the coding or shell task delegated by the parent agent. Inspect
          relevant code first, make minimal focused changes, and verify the result.
          Keep shell commands within the delegated scope and respect approval rules.
          Preserve unrelated work. Do not commit, push, or deploy unless explicitly
          requested. Report changes, commands run, verification results, and blockers
          to the parent agent.
        '';
      };
      permission = {
        bash = "ask";
        external_directory = "ask";
        doom_loop = "ask";
        read = {
          "*" = "allow";
          "*.env" = "deny";
          "*.env.*" = "deny";
          "*.env.example" = "allow";
          "*.key" = "deny";
          "*.pem" = "deny";
          "*/.ssh/*" = "deny";
          "*/opencode/auth.json" = "deny";
          "*/.webui_secret_key" = "deny";
          "*/secrets/location.nix" = "ask";
        };
      };
      mcp = {
        context7 = {
          type = "remote";
          url = "https://mcp.context7.com/mcp";
          oauth = false;
          headers.CONTEXT7_API_KEY = "{file:~/.config/opencode/context7.key}";
        };
      };
    };
  };
}
