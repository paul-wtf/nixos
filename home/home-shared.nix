{ ... }:
{
  imports = [
    ./program-configs/shared/starship.nix
    ./program-configs/shared/fish.nix
    ./program-configs/shared/vim.nix
    ./program-configs/shared/kitty.nix
    ./program-configs/shared/alacritty.nix
    ./program-configs/shared/tmux.nix
    ./program-configs/shared/hyfetch.nix
    ./program-configs/shared/fastfetch.nix
    ./program-configs/shared/claude-code.nix
    ./program-configs/shared/claude-memory-sync.nix
    ./program-configs/shared/theming.nix
    ./program-configs/shared/ssh.nix
    ./program-configs/shared/thunderbird.nix
  ];

  home.stateVersion = "26.05";
}
