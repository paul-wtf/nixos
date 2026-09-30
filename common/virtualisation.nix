{ ... }:
{
  virtualisation.libvirtd.enable = true;
  # libvirtd pulls in machined.service directly, which doesn't want its socket; the socket then refuses to start.
  systemd.services.systemd-machined.wants = [ "systemd-machined.socket" ];
  programs.virt-manager.enable = true;

  # Rootless containers, for working on the Spawnery images by hand.
  #
  # The images themselves are built with nixpkgs' dockerTools, which needs no
  # daemon and gives reproducible output; podman is here to run and inspect the
  # result without booting a VM first, and to back `kind` for a throwaway
  # cluster. `k3d` stays unusable — it talks to Docker's API specifically.
  #
  # containers.enable is what sets up the subuid/subgid ranges rootless mode
  # needs; dockerCompat provides `docker` as an alias for tools that expect it.
  virtualisation.containers.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dnsname.enable = true;
  };

  users.users.paul.extraGroups = [ "libvirtd" ];
}
