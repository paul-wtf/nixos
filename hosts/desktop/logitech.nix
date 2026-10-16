{ lib, pkgs, ... }:
{
  # Solaar over Piper: libratbag has no device entry for the PRO X Superlight 2
  # (046d:40a9), while Solaar probes HID++ 2.0 features at runtime.
  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };

  # Settings outside an onboard profile are reapplied by Solaar on reconnect,
  # so it has to keep running.
  systemd.user.services.solaar = {
    description = "Solaar";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${lib.getExe pkgs.solaar} --window=hide";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
