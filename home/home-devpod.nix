{ lib, pkgs, ... }:
{
  imports = [
    ./home-headless.nix
    ./program-configs/linux/gpg-agent.nix
  ];

  home.username = "paul";
  home.homeDirectory = "/home/paul";
  targets.genericLinux.enable = true;

  services.gpg-agent.pinentry.package = lib.mkForce pkgs.pinentry-curses;

  programs.ssh.settings."*" = {
    User = "root";
    IdentityAgent = "\${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.ssh";
  };

  programs.claude-code.settings = {
    model = "opus[1m]";
    inputNeededNotifEnabled = true;
    agentPushNotifEnabled = true;
    defaultToAgentsView = false;
  };

  home.packages = with pkgs; [ kubectl fluxcd gh go jdk jq kubelogin-oidc ];
}
