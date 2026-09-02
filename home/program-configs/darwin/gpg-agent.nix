{ pkgs, ... }:
{
  # The macOS counterpart of linux/gpg-agent.nix: gpg-agent as launchd agent,
  # serving git's OpenPGP signatures and, as the SSH agent, the authentication
  # subkey of A86663FE8C6B0713. It replaces the ~/.ssh/id_ed25519 pin for
  # GitHub; the macOS ssh-agent and Keychain stay for everything else.
  programs.gpg.enable = true;

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    # The authentication subkey 0DB880C493B477BD, by keygrip (see linux/gpg-agent.nix).
    sshKeys = [ "53D5539748A47533E578E461762E97FA1D3D8F6A" ];
    pinentry.package = pkgs.pinentry_mac;
    defaultCacheTtl = 28800;
    maxCacheTtl = 86400;
    defaultCacheTtlSsh = 28800;
    maxCacheTtlSsh = 86400;
  };

  # home-manager's launchd socket lives here on macOS (no XDG_RUNTIME_DIR);
  # the path is the module's own, computed for the default GNUPGHOME.
  programs.ssh.settings."github.com".IdentityAgent =
    "/private/var/run/org.nix-community.home.gpg-agent/S.gpg-agent.ssh";

  # git is not configured by nix-darwin the way common/programs.nix does it on
  # NixOS, so the signing half lives here. Identity (user.name/email) stays in
  # the machine's own ~/.gitconfig -- which must not carry gpg.format=ssh any
  # more, because ~/.gitconfig is read after this file and would win.
  programs.git = {
    enable = true;
    signing = {
      key = "1BDC71D099F85D10!";
      format = "openpgp";
      signByDefault = true;
    };
    settings.tag.gpgsign = true;
  };
}
