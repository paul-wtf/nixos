{ pkgs, ... }:
let
  # The panel shows only ~2556 of the 2560 columns it accepts, so the 4 missing
  # pixels cannot be recovered -- only moved. 50 is the factory position and
  # hides them all on the left, where the cursor lives; one step is ~1px.
  position = 51;
  serial = "035925325656";

  # The scaler acts on a *change* of VCP 0x20, not on its value, and every
  # re-sync (modeset, DPMS wake) drops the real position while the register
  # keeps whatever was written -- so writing the target alone is a no-op after
  # a boot. Feature 06 puts register and reality back on the factory value,
  # which makes the following write a change again.
  apply = pkgs.writeShellScript "xeneon-edge-position" ''
    ddcutil=${pkgs.ddcutil}/bin/ddcutil
    for _ in $(seq 30); do
      if $ddcutil --sn ${serial} setvcp 06 1; then
        sleep 2
        $ddcutil --sn ${serial} setvcp 20 ${toString position} && exit 0
      fi
      sleep 2
    done
    exit 1
  '';
in
{
  hardware.i2c.enable = true;
  users.users.paul.extraGroups = [ "i2c" ];
  environment.systemPackages = [ pkgs.ddcutil ];

  # In the session rather than at boot: a system unit on graphical.target runs
  # before the login and thus before Hyprland's modeset, which undoes it.
  home-manager.users.paul.systemd.user.services.xeneon-edge-position = {
    Unit = {
      Description = "Horizontal image position of the XENEON EDGE (DDC/CI)";
      After = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "oneshot";
      ExecStart = "${apply}";
    };
  };
}
