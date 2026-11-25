{ ... }:
{
  imports = [
    ./home-headless.nix
    ./program-configs/shared/kitty.nix
    ./program-configs/shared/alacritty.nix
    ./program-configs/shared/thunderbird.nix
  ];
}
