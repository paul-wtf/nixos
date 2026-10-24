{ config, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;

  hardware.nvidia = {
    open = true;
    # Drop once NixOS/nixpkgs#576397 is in nixos-unstable: patchelf 0.19.2 maps .dynamic
    # read-only when interpreter and rpath are set in one call, so ld.so segfaults.
    package = config.boot.kernelPackages.nvidiaPackages.latest.overrideAttrs (old: {
      postInstall = toString old.postInstall + ''
        for i in nvidia-cuda-mps-control nvidia-cuda-mps-server nvidia-smi nvidia-debugdump nvidia-powerd; do
          if [ -e $bin/origBin/$i ]; then
            install -Dm755 $bin/origBin/$i $bin/bin/$i
            patchelf --set-rpath $out/lib:$libPath $bin/bin/$i
            patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $bin/bin/$i
          fi
        done
      '';
    });
    powerManagement.enable = true;   # NVreg_PreserveVideoMemoryAllocations=1 (Suspend/Resume)
  };
}
