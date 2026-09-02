{ pkgs, catppuccin, ... }:
{
  imports = [ catppuccin.nixosModules.catppuccin ];

  # X11 greeter: reliable on NVIDIA. Does NOT turn the session into X11 --
  # Hyprland still starts as a Wayland session; X is only for the login window.
  services.xserver.enable = true;

  services.displayManager.sddm = {
    enable = true;
    package = pkgs.kdePackages.sddm;   # Qt6 - required by the Catppuccin theme
  };
  services.displayManager.defaultSession = "hyprland-uwsm";

  # gnome-keyring as secret service (org.freedesktop.secrets), unlocked
  # automatically with the login password at login. tidal-hifi
  # (--password-store=gnome-libsecret) needs this, otherwise TidaLuna asks
  # for plugin permissions again on every start.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  # gnome-keyring by default also enables gcr-ssh-agent. Under Hyprland,
  # however, it has no working passphrase prompt (no gnome-shell/gcr-prompter),
  # so every SSH signature hangs (git clone/push blocks at "Cloning into...").
  # The secret service (org.freedesktop.secrets) for tidal stays active - only
  # the SSH part is disabled. The SSH agent is gpg-agent, run by home-manager
  # (services.gpg-agent) in home/program-configs/linux/gpg-agent.nix.
  services.gnome.gcr-ssh-agent.enable = false;

  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
    accent = "teal";
    sddm.enable = true;
  };
}
