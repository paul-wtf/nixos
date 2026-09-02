{ ... }:
{
  programs.ssh = {
    enable = true;
    # our own defaults instead of the (deprecated) home-manager presets
    enableDefaultConfig = false;

    settings = {
      # Load keys into the agent automatically on first use.
      "*".AddKeysToAgent = "yes";

      # github: which key is per platform -- linux/gpg-agent.nix names the
      # gpg-agent that serves the OpenPGP authentication subkey, darwin/ssh.nix
      # keeps the machine's ~/.ssh/id_ed25519.
      "github.com".User = "git";
    };
  };
}
