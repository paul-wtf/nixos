{ ... }:
{
  imports = [
    ./home-shared.nix
    ./program-configs/darwin/ssh.nix
    ./program-configs/darwin/gpg-agent.nix
    ./program-configs/darwin/fish.nix
    ./program-configs/darwin/hyfetch.nix
  ];

  home.username = "paulweber";
  home.homeDirectory = "/Users/paulweber";
}
