{ config, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;

  hardware.nvidia = {
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    powerManagement.enable = true;   # NVreg_PreserveVideoMemoryAllocations=1 (Suspend/Resume)
  };
}
