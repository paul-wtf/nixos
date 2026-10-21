{ ... }:
{
  # Login is a one-time interactive step with the service stopped:
  #   systemctl --user stop protonmail-bridge; protonmail-bridge --cli
  # Credentials land in gnome-keyring via the Secret Service.
  services.protonmail-bridge.enable = true;
}
