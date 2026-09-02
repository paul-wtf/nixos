{ ... }:
{
  imports = [
    ./home-shared.nix
    ./program-configs/linux/hyprland.nix
    ./program-configs/linux/quickshell.nix
    ./program-configs/linux/hyprlock.nix
    ./program-configs/linux/vencord.nix
    ./program-configs/linux/brave.nix
    ./program-configs/linux/theming.nix
    ./program-configs/linux/rofi.nix
    ./program-configs/linux/xdg-mime.nix
    ./program-configs/linux/gpg-agent.nix
  ];

  home.username = "paul";
  home.homeDirectory = "/home/paul";
}
