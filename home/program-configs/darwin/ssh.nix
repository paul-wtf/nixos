{ ... }:
{
  # macOS has a system-provided ssh-agent (no systemd needed). UseKeychain
  # loads the passphrase from the macOS keychain; together with AddKeysToAgent
  # (shared) the key is unlocked once and never asked for again.
  programs.ssh.settings."*" = {
    UseKeychain = "yes";
    # UseKeychain is an Apple patch; upstream OpenSSH from Nix (e.g. in the PATH
    # of the claudeMemorySync activation script) otherwise aborts with "Bad
    # configuration option". IgnoreUnknown lets non-Apple ssh variants skip the
    # option. (Must come BEFORE UseKeychain in the config file - guaranteed
    # because home-manager's ssh module special-cases IgnoreUnknown and always
    # emits it first in each block.)
    IgnoreUnknown = "UseKeychain";
  };

  # github: this machine's own key, as before. The gpg-agent route that
  # linux/gpg-agent.nix takes is not set up on macOS yet.
  programs.ssh.settings."github.com" = {
    IdentityFile = "~/.ssh/id_ed25519";
    IdentitiesOnly = "yes";
  };
}
