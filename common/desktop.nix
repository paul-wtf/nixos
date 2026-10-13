{ pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;   # Hyprland via Universal Wayland Session Manager
  };
  # Portal startup order: otherwise xdg-desktop-portal (frontend) only hangs
  # off session.slice and thus starts BEFORE xdg-desktop-portal-hyprland, which
  # only comes up after graphical-session.target (compositor). The frontend
  # then reads the Hyprland backend's AvailableCursorModes as 0 and caches that
  # permanently -> Discord's screenshare request with cursor_mode=2 (embedded)
  # is rejected with "Unavailable cursor mode 2", SelectSources fails, the
  # hyprland-share-picker never appears. Fix: start the frontend only after the
  # backend so it reads the real cursor modes (3 = hidden|embedded).
  systemd.user.services.xdg-desktop-portal = {
    overrideStrategy = "asDropin";
    after = [ "xdg-desktop-portal-hyprland.service" ];
    wants = [ "xdg-desktop-portal-hyprland.service" ];
    # The default unit PATH would shadow the session PATH, and GLib then drops
    # every .desktop file whose Exec is not absolute from OpenURI's app list.
    enableDefaultPath = false;
  };

  # Thunar file manager (no HM module available -> NixOS module).
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin   # Right-click: extract/create archives
      thunar-volman           # Auto-mount USB devices
    ];
  };
  programs.xfconf.enable = true;    # Persist Thunar settings
  services.gvfs.enable = true;      # Trash, mounting, network (smb/ftp), MTP
  services.tumbler.enable = true;   # Thumbnails (images/PDF/video)
}
