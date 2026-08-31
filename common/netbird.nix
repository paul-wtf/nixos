{ ... }:
{
  # NetBird client against the self-hosted management server. `enable = true`
  # is the backward-compatible single-client setup: netbird.service listening
  # on UDP 51820, interface wt0, non-hardened. The module also installs the
  # `netbird` and `netbird-ui` wrappers, keeps wt0 out of NetworkManager and
  # dhcpcd, and opens the firewall port for direct peer-to-peer traffic.
  services.netbird.enable = true;

  # The daemon persists the management URL in config.json, where the Go type
  # behind it is a *url.URL carrying no JSON tags -- so it serialises as an
  # object rather than a string. netbird appends ":443" itself whenever a URL
  # has no port, so spelling the port out here keeps the module's config.d
  # merge from rewriting config.json on every start.
  services.netbird.clients.default.config.ManagementURL = {
    Scheme = "https";
    Host = "vpn.coding-area.net:443";
  };
}
