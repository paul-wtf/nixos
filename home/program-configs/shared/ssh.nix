{ ... }:
{
  programs.ssh = {
    enable = true;
    # our own defaults instead of the (deprecated) home-manager presets
    enableDefaultConfig = false;

    settings = {
      # Load keys into the agent automatically on first use.
      "*".AddKeysToAgent = "yes";

      # github: the key comes from gpg-agent, which serves the OpenPGP
      # authentication subkey -- named as IdentityAgent in linux/gpg-agent.nix
      # and darwin/gpg-agent.nix, because the socket path differs per platform.
      "github.com".User = "git";
    };
  };
}
