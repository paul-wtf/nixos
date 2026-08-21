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
      ./dac-keepalive.nix
      ./rodecaster-volume-bridge.nix
      ./mangohud.nix
      ./hyprland-monitors.nix
    ];
  networking.hostName = "paul-desktop";
  system.stateVersion = "26.05";
}
