{ pkgs, config, ... }:
let
  # Askpass helper: reads the key passphrase from the gnome-keyring.
  #
  # The passphrase is stored under gnome-keyring's own ssh-store attributes
  # (label "Unlock password for: paul@paul-desktop"), not under a hand-rolled
  # schema. That entry was created by gcr-ssh-agent, which common/sddm.nix
  # disables because it has no working prompt under Hyprland -- the stored
  # secret outlives the agent, so we just read it directly.
  #
  # Since nothing recreates it automatically any more, restore it like this if
  # the keyring is ever reset (prompts for the passphrase):
  #   secret-tool store --label='Unlock password for: paul@paul-desktop' \
  #       unique "ssh-store:${config.home.homeDirectory}/.ssh/id_ed25519"
  keyringAskpass = pkgs.writeShellScript "ssh-askpass-keyring" ''
    exec ${pkgs.libsecret}/bin/secret-tool lookup \
      unique "ssh-store:${config.home.homeDirectory}/.ssh/id_ed25519"
  '';
in
{
  # secret-tool for one-time storing/reading of the passphrase
  home.packages = [ pkgs.libsecret ];

  # Persistent OpenSSH agent as a systemd user service.
  services.ssh-agent.enable = true;

  # Automatically loads the key into the agent at login (passphrase from gnome-keyring).
  systemd.user.services.ssh-add-key = {
    Unit = {
      Description = "Load SSH key into the agent with passphrase from gnome-keyring";
      After = [ "ssh-agent.service" "graphical-session.target" ];
      Requires = [ "ssh-agent.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "SSH_AUTH_SOCK=%t/ssh-agent"
        "SSH_ASKPASS=${keyringAskpass}"
        "SSH_ASKPASS_REQUIRE=force"
      ];
      ExecStart = "${pkgs.openssh}/bin/ssh-add %h/.ssh/id_ed25519";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
