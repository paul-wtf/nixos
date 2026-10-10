{ ... }:
{
  # No DNS entry: the tunnel only routes the internal ranges, so the system
  # resolver stays in charge.
  networking.wg-quick.interfaces.mgmt = {
    address = [ "10.40.0.159/24" ];
    privateKeyFile = "/etc/wireguard/mgmt.key";
    peers = [
      {
        publicKey = "rvbU+cSE+me4CO2Aduy2ReZUNMYcN8L1tjVDhO9hqVY=";
        allowedIPs = [ "10.1.90.0/24" "10.30.0.0/16" ];
        endpoint = "mgmt.as49581.net:13231";
        persistentKeepalive = 25;
      }
    ];
  };
}
