{ pkgs, dotfiles, ... }:
let
  # Only the colours hyprland.lua actually uses; the full palette moves into the
  # shared module later. Quickshell's Theme.qml hardcodes the same literals in
  # its hyprctl eval payload -- keep them in sync.
  #
  # Stored as bare hex so the opaque and the translucent form of a colour cannot
  # drift apart: the glow gradient is the same sky/teal at 40% alpha.
  sky   = "89dceb";
  teal  = "94e2d5";
  crust = "11111b";
  surface = "45475a";

  rgb  = hex: "rgb(${hex})";
  rgba = hex: alpha: "rgba(${hex}${alpha})";
in
{
  # XWayland starts with an empty RESOURCE_MANAGER property because nothing in a
  # uwsm/Hyprland session runs xrdb (an X11 session's xinit would). Programs that
  # read the X resource database without a NULL check then crash: FurMark's
  # X11_GetMonitorDPI() passes XResourceManagerString()'s NULL straight into
  # XrmGetStringDatabase() -> strlen(NULL) -> SIGSEGV, so pressing "Run Test"
  # silently kills the benchmark process. Xft.dpi 96 is what toolkits already
  # assume when the resource is unset, so this only fills the database.
  xresources.properties = {
    "Xft.dpi" = 96;
  };

  wayland.windowManager.hyprland = {
    enable = true;

    package = null;
    portalPackage = null;

    # Session management is done by uwsm; the HM integration (default true) fires
    # `systemctl --user stop hyprland-session.target` on start, which since an HM
    # update tears down the entire uwsm session (incl. compositor) via
    # PropagatesStopTo=graphical-session.target -> Hyprland exits ~2s after login.
    systemd.enable = false;

    # Hyprland 0.57 removes the .conf format. 0.56 still accepts both, and
    # Hyprland prefers hyprland.lua whenever it exists -- so flipping this back
    # to "hyprlang" is a complete rollback.
    configType = "lua";

    # NOTE: Session env lives in ~/.config/uwsm/env-hyprland (see below).
    # An hl.env block would only inherit to direct exec_cmd children, not to
    # `uwsm app` scopes or D-Bus services. UWSM loads the uwsm env file into the
    # systemd user environment before the compositor -> all inherit consistently.

    extraLuaFiles = {
      binds = ./hypr/binds.lua;
      animations = ./hypr/animations.lua;

      # Autostart lives here rather than in a plain .lua file because it needs
      # the ${dotfiles} store path interpolated.
      autostart = ''
        hl.on("hyprland.start", function()
            -- UWSM readiness: signals to wayland-wm@hyprland.service that the
            -- compositor is up. Exports WAYLAND_DISPLAY/DISPLAY into the systemd
            -- user and D-Bus environment and activates graphical-session.target.
            -- MUST run first, otherwise the session unit hangs in the activating
            -- timeout.
            hl.exec_cmd("uwsm finalize")

            -- Load ~/.Xresources into XWayland's RESOURCE_MANAGER (see the
            -- xresources block above for why). Home Manager only merges it in its
            -- activation script and via xsession.profileExtra, and neither runs on
            -- a uwsm login -- so without this the property is empty after every
            -- reboot. Connecting also starts XWayland if it is still lazy.
            hl.exec_cmd("${pkgs.xrdb}/bin/xrdb -merge $HOME/.Xresources")

            -- NVIDIA 3-display cold-boot bug: if all monitors come up at the same time,
            -- the main monitor does not get 4K@240 (DSC/head allocation). Fix: briefly take
            -- DP-2 out (main jumps to 240), then back via reload with the full HDR config.
            -- `hyprctl keyword` does not work under the Lua config manager (returns
            -- "keyword can't work with non-legacy parsers. Use eval."), so the disable step
            -- now calls hl.monitor() directly instead of shelling out; the restore step still
            -- goes through `hyprctl reload` (unaffected by the keyword restriction) so it
            -- picks the full HDR config back up from hyprland-monitors.nix instead of
            -- guessing at hl.monitor's re-enable fields. Only needed if the cold-boot bug
            -- reappears.
            -- hl.timer(function()
            --     hl.monitor({ output = "DP-2", disabled = true })
            --     hl.monitor({ output = "DP-3", disabled = true })
            --     hl.timer(function()
            --         hl.exec_cmd("hyprctl reload")
            --     end, { timeout = 1000, type = "oneshot" })
            -- end, { timeout = 3000, type = "oneshot" })

            -- GUI apps via `uwsm app --`: they land in their own systemd scopes
            -- (app.slice) instead of as children of the compositor -> clean
            -- stopping at session end, own cgroup/OOM limits, correct placement
            -- in the session tree.
            hl.exec_cmd("uwsm app -- quickshell")
            hl.exec_cmd("uwsm app -- discord")

            -- Tidal (Electron/Chromium) prefers PulseAudio but falls back to ALSA
            -- if it gets no connection to pipewire-pulse at startup.
            -- pipewire-pulse.service is socket-activated (Type=simple): the socket
            -- is there early, but the service only starts COLD on the first client
            -- connect. At boot, Tidal's connect triggers this cold start, whose
            -- latency runs into Chromium's Pulse handshake timeout -> ALSA
            -- fallback. Depending on backend, Tidal registers with WirePlumber
            -- under a different identity (pulse=Chromium, alsa=PipeWire ALSA
            -- [tidal-hifi]), which makes the target set in pavucontrol / via the
            -- pulse.rules get lost after a restart.
            -- Fix: explicitly warm-start pipewire-pulse BEFORE Tidal (systemctl
            -- start blocks until active) so that Tidal deterministically goes via
            -- PulseAudio and the pulse.rules rule (see hosts/desktop/pipewire.nix)
            -- takes effect.
            hl.exec_cmd("systemctl --user start pipewire-pulse.service; uwsm app -- tidal-hifi")

            hl.exec_cmd("uwsm app -- awww-daemon")
            hl.exec_cmd("sleep 1; awww img ${dotfiles}/wallpapers/firewatchcatpuccinmochagreen.png")
            hl.exec_cmd("uwsm app -- streamcontroller -b")
            hl.exec_cmd("uwsm app -- steam -silent")
            hl.exec_cmd("uwsm app -- gsr-ui")
            hl.exec_cmd("uwsm app -- Telegram -startintray")
            hl.exec_cmd("uwsm app -- seadrive-gui")
        end)
      '';
    };

    settings = {
      # Each attribute renders as an hl.<name>(...) call; list values render one
      # call per element.
      config = {
        general = {
          gaps_in = 5;
          # Defaults = zen variant (quickshell Theme.qml couples at runtime on
          # theme switch via `hyprctl eval`: zen -> these values,
          # mocha/liquidglass -> 10 / sky..teal 45deg / 10)
          gaps_out = { top = 12; right = 22; bottom = 22; left = 22; };
          border_size = 2;
          col = {
            active_border = rgb teal;
            inactive_border = rgba surface "aa";
          };
          resize_on_border = false;
          allow_tearing = false;
          layout = "dwindle";
        };

        decoration = {
          rounding = 12;
          rounding_power = 2;
          active_opacity = 1.0;
          inactive_opacity = 1.0;
          shadow = { enabled = true; range = 4; render_power = 3; color = rgba crust "ee"; };
          blur = { enabled = true; size = 6; passes = 2; vibrancy = 0.1696; new_optimizations = false; };
          motion_blur = { enabled = true; samples = 7; };
          # The look lives entirely here; Theme.qml only toggles enabled (zen ->
          # false, mocha/liquidglass -> true). Inactive windows transparent ->
          # focus indicator.
          glow = {
            enabled = false;
            range = 10;
            render_power = 3;
            color = { colors = [ (rgba sky "66") (rgba teal "66") ]; angle = 45; };
            color_inactive = rgba "000000" "00";
          };
        };

        dwindle = { preserve_split = true; };
        master = { new_status = "master"; };

        # Native scrolling layout (since Hyprland 0.51, usable here via toggle
        # SUPER+TAB).
        scrolling = {
          column_width = 0.5;                                # default width of new columns (0.1-1.0)
          focus_fit_method = 1;                              # fit the focused column instead of centering (0=center, 1=fit)
          explicit_column_widths = "0.333, 0.5, 0.667, 1.0"; # presets that colresize +conf/-conf cycles through
          # direction = "right";                             # direction in which new columns grow (left/right/down/up)
        };

        misc = { force_default_wallpaper = -1; disable_hyprland_logo = false; };

        render = {
          # use_shader_blur_blend = true;
          direct_scanout = false;
          cm_sdr_eotf = "gamma22";
          cm_auto_hdr = 0;
        };

        input = {
          kb_layout = "de";
          accel_profile = "flat";
          follow_mouse = 1;
          sensitivity = -0.1;
          touchpad = {
            natural_scroll = true;
            scroll_factor = 0.2;
          };
        };

        xwayland = { enabled = true; force_zero_scaling = true; };
      };

      gesture = [ { fingers = 3; direction = "horizontal"; action = "workspace"; } ];

      device = [ { name = "epic-mouse-v1"; sensitivity = -0.5; } ];

      layer_rule = [
        { name = "quickshell-blur"; match = { namespace = "quickshell"; }; blur = true; ignore_alpha = 0.05; }
      ];

      window_rule = [
        { name = "suppress-maximize-events"; match = { class = ".*"; }; suppress_event = "maximize"; }
        { name = "fix-xwayland-drags"; match = { class = "^$"; title = "^$"; xwayland = true; float = true; fullscreen = false; pin = false; }; no_focus = true; }
        { name = "move-hyprland-run"; match = { class = "hyprland-run"; }; move = "20 monitor_h-120"; float = true; }
        { name = "discord-position"; match = { class = "^discord$"; }; workspace = "2"; }
        { name = "tidal-position"; match = { class = "^tidal-hifi$"; }; workspace = "2"; }
        { name = "steam-bigpicture"; match = { class = "^steam$"; title = "^Steam Big Picture Mode$"; }; monitor = "HDMI-A-1"; fullscreen = true; }
        # Class prefix follows CHROME_WRAPPER, so it is brave-origin now; the optional
        # group keeps the rule working if we ever go back to the regular Brave build.
        { name = "bitwarden-extension"; match = { class = "^brave(-origin)?-nngceckbapebfimnlniiiahkandclblb-Default$"; }; float = true; }
        { name = "thunar-file-operation-float"; match = { class = "^thunar$"; title = "^File Operation Progress$"; }; float = true; size = "600 300"; center = true; }
      ];
    };
  };

  # UWSM session environment: sourced BEFORE the compositor and loaded into the
  # systemd user + D-Bus activation environment. Thus reaches the compositor
  # itself, all `uwsm app` scopes and D-Bus-activated services (in contrast to an
  # hl.env block, which only reaches direct children). Single source of truth.
  xdg.configFile."uwsm/env-hyprland".text = ''
    export XCURSOR_SIZE=24
    export XCURSOR_THEME=catppuccin-mocha-dark-cursors
    export HYPRCURSOR_SIZE=24
    export QT_QPA_PLATFORMTHEME=qt6ct
    export QT_STYLE_OVERRIDE=kvantum
  '';

  # Companion tools the session needs NOW (launcher). Grows in round 2.
  # playerctl backs the XF86AudioNext/Pause/Play/Prev binds in hypr/binds.lua. It
  # was never declared anywhere, so those four keys had been dead since long
  # before the Lua migration -- the binds fire, they just called a missing binary.
  home.packages = with pkgs; [ rofi quickshell jq cava awww playerctl ];
}
