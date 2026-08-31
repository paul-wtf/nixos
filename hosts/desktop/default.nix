{ ... }:
{
  imports = [
    ../../common
    ./hardware-configuration.nix
    ./boot.nix
    ./nvidia.nix
    ../../common/sddm.nix
    ./audio.nix
    ./gaming.nix
    ./coolercontrol.nix
    ./lact.nix
    ./streamcontroller.nix
    ./vr.nix
  ];

  home-manager.users.paul.imports =
    [
      ./pipewire.nix
      ./rodecaster-volume-bridge.nix
      ./mangohud.nix
      ./hyprland-monitors.nix
    ];
  networking.hostName = "paul-desktop";

  # Minecraft (25565) for other NetBird peers only -- scoped to wt0 so the
  # server stays invisible on the LAN and from the internet.
  networking.firewall.interfaces.wt0.allowedTCPPorts = [ 25565 ];
  system.stateVersion = "26.05";
}
