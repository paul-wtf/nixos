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

      # paulwtf hosts, SSH only on 41222 (fluxcd docs/access.md). host01 and
      # dev have no public address and are reached through server01.
      server01 = { HostName = "45.137.203.198"; User = "admin"; Port = "41222"; };
      server02 = { HostName = "45.13.227.226"; User = "admin"; Port = "41222"; };
      server03 = { HostName = "185.117.3.72"; User = "admin"; Port = "41222"; };
      pelican = { HostName = "45.137.203.195"; User = "admin"; Port = "41222"; };
      host01 = { HostName = "10.1.90.1"; User = "admin"; Port = "41222"; ProxyJump = "server01"; };
      dev = { HostName = "10.1.90.12"; User = "paul"; Port = "41222"; ProxyJump = "server01"; };
    };
  };
}
