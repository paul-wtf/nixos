{ pkgs, ... }:
let
  # Files younger than a minute may still be written by gpu-screen-recorder.
  sync = pkgs.writeShellApplication {
    name = "clips-sync";
    runtimeInputs = [ pkgs.rsync pkgs.openssh pkgs.findutils ];
    text = ''
      cd "$HOME/Videos/Clips"
      find . -type f -mmin +1 -printf '%P\n' \
        | rsync -a --numeric-ids --files-from=- \
            -e "ssh -i $HOME/.ssh/clips-sync -o IdentitiesOnly=yes -o IdentityAgent=none -o BatchMode=yes -o ConnectTimeout=10" \
            . root@10.1.90.1:
    '';
  };
in
{
  networking.wg-quick.interfaces.mgmt.autostart = true;

  # host01 pins the clips-sync key to `rrsync -wo /srv/nfs/fireshare/videos`.
  home-manager.users.paul.systemd.user = {
    services.clips-sync = {
      Unit.Description = "Copy new gpu-screen-recorder clips to Fireshare";
      Service = {
        Type = "oneshot";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/Videos/Clips";
        ExecStart = "${sync}/bin/clips-sync";
      };
    };
    timers.clips-sync = {
      Unit.Description = "Copy new gpu-screen-recorder clips to Fireshare";
      Timer = {
        OnBootSec = "2min";
        OnUnitActiveSec = "2min";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
