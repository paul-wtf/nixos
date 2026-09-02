{ pkgs, ... }:
{
  # gpg-agent is both the OpenPGP agent git signs through and the SSH agent.
  # It replaces services.ssh-agent plus the ssh-add-key unit that fetched the
  # ~/.ssh/id_ed25519 passphrase from gnome-keyring: the key ssh now offers is
  # the authentication subkey of A86663FE8C6B0713, named below by keygrip, and
  # its passphrase is what pinentry asks for once per cache period.
  programs.gpg.enable = true;

  # GitHub authenticates with the authentication subkey. Named per host rather
  # than through SSH_AUTH_SOCK alone, so that an SSH session into this machine
  # -- whose fish init leaves a forwarded agent in place -- still reaches
  # GitHub through gpg-agent. ssh expands the variable itself.
  programs.ssh.settings."github.com".IdentityAgent = "\${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.ssh";

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    # The authentication subkey 0DB880C493B477BD. gpg-agent offers ssh only the
    # keygrips written to sshcontrol, and this option writes them.
    sshKeys = [ "53D5539748A47533E578E461762E97FA1D3D8F6A" ];
    # A Qt pinentry: under Hyprland there is no gcr-prompter for the GNOME one
    # (see common/sddm.nix), and the curses one has no terminal to draw on when
    # git is invoked from a GUI or from a Claude Code session.
    pinentry.package = pkgs.pinentry-qt;
    # One unlock carries a working day; a Claude Code session has no way to
    # answer a pinentry itself and rides on the cache.
    defaultCacheTtl = 28800;
    maxCacheTtl = 86400;
    defaultCacheTtlSsh = 28800;
    maxCacheTtlSsh = 86400;
  };
}
