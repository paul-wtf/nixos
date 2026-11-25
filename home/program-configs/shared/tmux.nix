{ ... }:
let
  # Nerd Font glyphs as escapes (same pattern as starship.nix) so the
  # invisible private-use characters do not get lost in editor/copy
  # roundtrips. Codepoints > U+FFFF need JSON surrogate pairs.
  sepLeft     = builtins.fromJSON ''"\ue0b2"'';        # Powerline arrow left
  sepRight    = builtins.fromJSON ''"\ue0b0"'';        # Powerline arrow right
  iconApp     = builtins.fromJSON ''"\uf1ae"'';        # Application
  iconDir     = builtins.fromJSON ''"\uf07b"'';        # Folder
  iconHost    = builtins.fromJSON ''"\udb81\udc8b"''; # Host (U+F048B, surrogate pair)
  iconSession = builtins.fromJSON ''"\ue795"'';        # Session/terminal
  iconClock   = builtins.fromJSON ''"\udb80\udcf0"''; # Date/time (U+F00F0, surrogate pair)
in
{
  programs.tmux = {
    enable = true;

    mouse = true;
    historyLimit = 50000;
    keyMode = "vi";
    terminal = "tmux-256color";

    # Replaces the tmux-sensible plugin (previously ran via TPM). HM loads it
    # at the beginning of the config; the values below it would otherwise
    # override sensible again, hence explicitly set to the sensible/tmux defaults.
    sensibleOnTop = true;
    escapeTime = 0;
    focusEvents = true;
    aggressiveResize = true;
    clock24 = true;

    # Lands AFTER the plugin load in the tmux.conf — necessary because the
    # @thm_* variables only exist after the Catppuccin plugin has run.
    extraConfig = ''
      set -ga terminal-overrides ",xterm-kitty:Tc"
      set -ga terminal-overrides ",xterm-256color:RGB"
      set -g set-clipboard on
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded"

      # Click on a session name in the status bar -> switch to that
      # session. The names are marked via #[range=user|<session>] in
      # @catppuccin_session_text; with range=user, mouse_status_range
      # yields the session name, for windows the constant
      # "window" (then default behavior select-window).
      # switch-client -t does NOT expand formats -> go via run-shell,
      # which resolves #{mouse_status_range} before execution.
      bind -n MouseDown1Status {
        if -F "#{==:#{mouse_status_range},window}" {
          select-window -t=
        } {
          if -F "#{mouse_status_range}" {
            run-shell "tmux switch-client -t '#{mouse_status_range}'"
          }
        }
      }

      # ── Assemble the status bar after the plugin ───────────────────
      # Colorful module colors (Mocha) — with -F for format expansion
      set -gF @catppuccin_session_color "#{E:@thm_teal}"
      set -gF @catppuccin_application_color "#{E:@thm_blue}"
      set -gF @catppuccin_directory_color "#{E:@thm_yellow}"
      set -gF @catppuccin_host_color "#{E:@thm_green}"
      set -gF @catppuccin_date_time_color "#{E:@thm_mauve}"

      set -g status-left-length 100
      set -g status-right-length 100

      set -g status-left ""
      # Mask the left separator of the session block by forcing bg to teal
      set -ag status-left "#[bg=#{E:@thm_teal}]#{E:@catppuccin_status_session}"

      set -g status-right ""
      set -ag status-right "#{E:@catppuccin_status_application}"
      set -ag status-right "#{E:@catppuccin_status_directory}"
      set -ag status-right "#{E:@catppuccin_status_host}"
      set -ag status-right "#{E:@catppuccin_status_date_time}"
    '';
  };

  # The plugin itself comes via catppuccin.autoEnable (theming.nix); flavor
  # is set by the module from catppuccin.flavor. This block lands BEFORE the
  # plugin's run-shell — that is where the @catppuccin_* options must be.
  catppuccin.tmux.extraConfig = ''
    # ── Catppuccin Mocha Teal Powerline ─────────────────────────────
    # Arrow separators (slanted = classic powerline arrow)
    set -g @catppuccin_window_status_style 'slanted'

    # Active window: teal background as accent
    set -g @catppuccin_window_current_background "#{@thm_teal}"

    # Date format: weekday + day.month + time
    set -g @catppuccin_date_time_text    "  %a %d.%m %H:%M "

    # Directory in the status bar shows the basename of the pane path
    set -g @catppuccin_directory_text "  #{b:pane_current_path} "

    # Extra padding for modules
    set -g @catppuccin_application_text  "  #{pane_current_command} "
    set -g @catppuccin_host_text         "  #H "
    # List all sessions of the tmux server (not just the current one): the
    # native #{S:...} loop iterates over all sessions. The active/attached
    # session teal + bold, the rest dimmed.
    set -g @catppuccin_session_text      "  #{S:#[range=user|#{session_name}]#{?session_attached,#[fg=#{E:@thm_teal}]#[bold]#{session_name}#[nobold],#[fg=#{E:@thm_overlay_1}]#{session_name}}#[fg=#{E:@thm_fg}]#[norange] }"
    set -g @catppuccin_window_default_text  "  #W "
    set -g @catppuccin_window_current_text  "  #W "

    # Powerline arrow separators between the status modules
    set -g @catppuccin_status_left_separator  "${sepLeft}"
    set -g @catppuccin_status_right_separator "${sepRight}"
    set -g @catppuccin_status_connect_separator "yes"
    set -g @catppuccin_status_fill "all"

    # More padding for icons in the module boxes
    set -g @catppuccin_application_icon  " ${iconApp} "
    set -g @catppuccin_directory_icon    " ${iconDir} "
    set -g @catppuccin_host_icon         " ${iconHost} "
    set -g @catppuccin_session_icon      " ${iconSession} "
    set -g @catppuccin_date_time_icon    " ${iconClock} "
  '';
}
