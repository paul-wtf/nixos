{ pkgs, ... }:
{
  systemd.user.services.dac-keepalive = {
    Unit = {
      Description = "D&A Alpha Hardware Gate Defeater";
      After = [ "pipewire-pulse.service" ];
      Requires = [ "pipewire-pulse.service" ];
    };
    Service = {
      Type = "simple";
      Environment = [ "PULSE_SINK=alsa_output.usb-D_A_D_A_Alpha-00.analog-stereo" ];
      ExecStart = "${pkgs.sox}/bin/play -q -n synth brownnoise vol 0.00001";
      Restart = "always";
      RestartSec = 3;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
