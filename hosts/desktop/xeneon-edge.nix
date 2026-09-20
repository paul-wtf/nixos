{ pkgs, ... }:
let
  # The panel shows only ~2556 of the 2560 columns it accepts, so the 4 missing
  # pixels cannot be recovered -- only moved. 50 is the factory position and
  # hides them on the left (where the cursor lives); one step is ~1px, so 54
  # trades them for the right edge, which carries Discord's icon column.
  position = 54;
  serial = "035925325656";
in
{
  hardware.i2c.enable = true;
  users.users.paul.extraGroups = [ "i2c" ];
  environment.systemPackages = [ pkgs.ddcutil ];

  # The scaler reports 0 for VCP 20 until something writes it, while actually
  # sitting at the factory value -- a written position therefore probably does
  # not survive a power cycle either, hence re-applying it on every boot.
  # DDC needs the panel awake, which it is not necessarily when the unit first
  # runs, so retry rather than order against something.
  systemd.services.xeneon-edge-position = {
    description = "Horizontal image position of the XENEON EDGE (DDC/CI)";
    wantedBy = [ "graphical.target" ];
    after = [ "graphical.target" ];
    serviceConfig = {
      Type = "oneshot";
      # ddcutil keeps its dynamic-sleep timings under XDG_CACHE_HOME and warns
      # three times per run when it cannot find one.
      CacheDirectory = "ddcutil";
      Environment = "XDG_CACHE_HOME=/var/cache";
      ExecStart = pkgs.writeShellScript "xeneon-edge-position" ''
        for _ in $(seq 30); do
          ${pkgs.ddcutil}/bin/ddcutil --sn ${serial} setvcp 20 ${toString position} && exit 0
          sleep 2
        done
        exit 1
      '';
    };
  };
}
