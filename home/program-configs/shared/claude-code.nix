{ ... }:
{
  # Claude Code declaratively via the home-manager module. It writes
  # ~/.claude/settings.json as a (read-only) Nix-store symlink — so change
  # settings HERE, not at runtime via /config (that would not persist).
  # The claude binary comes via home.packages from this module, which is
  # why it was removed from common/programs.nix. tmux itself stays
  # system-wide in common/programs.nix.
  programs.claude-code = {
    enable = true;

    settings = {
      # ── existing settings carried over ───────────────────────────────
      theme   = "dark-ansi";
      tui     = "fullscreen";
      verbose = false;
      model   = "claude-opus-5";
      # ── tmux ─────────────────────────────────────────────────────────
      # Agent teams run in tmux split-pane mode: every teammate gets a
      # pane of its own. "tmux" forces this (alternative: "auto" = only
      # if tmux/iTerm2 is present). Requires the experimental feature flag.
      teammateMode = "tmux";

      env = {
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";

        # Auto-updater off. On NixOS the claude binary lives immutable in
        # the Nix store; the updater tries to replace it, fails, and
        # blocks startup. There is no settings.json config key for this
        # (autoUpdates in ~/.claude.json is only app state) — the env variable
        # is the reliable kill switch and is applied before the updater
        # check. Updates come exclusively via nixos-rebuild.
        # DISABLE_UPDATES = "1" would additionally block manual `claude update`.
        DISABLE_AUTOUPDATER = "1";
      };

      permissions = {
        defaultMode = "auto";
        # Allow tmux commands without confirmation (send-keys, split-window, …).
        allow = [ "Bash(tmux:*)" ];
      };

      # Enable plugins declaratively. Format: "<plugin>@<marketplace>" = true.
      # Claude Code registers the marketplace "claude-plugins-official"
      # (anthropics/claude-plugins-official) itself on first start; here we only
      # set the enable flag — no interactive /plugin install needed (that would
      # want to write to the read-only settings.json and fail). code-review and
      # frontend-design live as first-party plugins directly in the marketplace
      # repo; superpowers (github.com/obra/superpowers) is fetched by Claude on
      # activation.
      enabledPlugins = {
        "superpowers@claude-plugins-official"     = true;
        "frontend-design@claude-plugins-official" = true;
        "code-review@claude-plugins-official"     = true;
      };
    };
  };
}
