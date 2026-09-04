{ ... }:
{
  imports = [
    ./locale.nix
    ./users.nix
    ./environment.nix
    ./programs.nix
    ./resolve-reencode.nix
    ./desktop.nix
    ./libinput.nix
    ./nix.nix
    ./fonts.nix
    ./sensors.nix
    ./hyprlock.nix
    ./brave-policies.nix
    ./sudo.nix
    ./virtualisation.nix
    ./netbird.nix
  ];

  networking.networkmanager.enable = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };
}
