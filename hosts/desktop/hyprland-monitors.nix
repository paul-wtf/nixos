{ ... }:
let
  # Shared HDR pipeline settings for both HDR-capable monitors (the laptop
  # panel in hosts/laptop/hyprland-monitors.nix uses the same values).
  hdr = {
    bitdepth = 10; cm = "hdredid";
    sdr_min_luminance = 0.005; sdr_max_luminance = 250;
    min_luminance = 0; max_luminance = 1000; sdr_eotf = "gamma22";
  };
in
{
  # Desktop-specific monitors + workspace assignment (pulled out of the shared
  # hyprland.nix; the laptop has its own counterpart).
  wayland.windowManager.hyprland.settings = {
    monitor = [
      ({
        output = "HDMI-A-1"; mode = "3840x2160@240.00"; position = "0x1440";
        scale = "1.0"; vrr = 2;
      } // hdr)
      ({
        output = "DP-2"; mode = "3440x1440@164.90"; position = "0x0";
        vrr = 2;
      } // hdr)
      { output = "DP-3"; mode = "2560x720@60"; position = "0x3600"; scale = "1.0"; }
    ];

    workspace_rule = [
      { workspace = "1"; monitor = "HDMI-A-1"; }
      # Tidal + Discord live here (window_rule in hyprland.nix) and should use
      # the full strip: a workspace rule beats general.gaps_*, so the runtime
      # `hyprctl eval` of a theme switch cannot put the gaps back.
      { workspace = "2"; monitor = "DP-3"; gaps_in = 0; gaps_out = 0; no_rounding = true; }
      { workspace = "3"; monitor = "DP-2"; }
    ];
  };
}
