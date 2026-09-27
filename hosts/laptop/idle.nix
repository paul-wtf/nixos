{ pkgs, ... }:
let
  # `hyprctl dispatch dpms on|off` is gone with the Lua config manager, and its
  # replacement hl.dsp.dpms only ever toggles -- it ignores the state argument,
  # so a resume could just as well switch the panel off. wlopm drives the
  # wlr-output-power protocol and takes an absolute state.
  wlopm = "${pkgs.wlopm}/bin/wlopm";
in
{
  # Idle management for the laptop (home-manager user service, only imported
  # here). Also covers closing the lid: the lid triggers suspend via the logind
  # default, and before_sleep_cmd locks BEFORE the suspend -> after opening
  # the lid the screen is locked and asks for the password.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd       = "pidof hyprlock || hyprlock";  # no duplicate instances
        before_sleep_cmd = "loginctl lock-session";      # lock before suspend/lid close
        after_sleep_cmd  = "${wlopm} --on '*'";    # display back on after resume
      };

      listener = [
        # 5 min: dim the screen (remember the brightness first)
        {
          timeout   = 300;
          on-timeout = "brightnessctl -s set 10%";
          on-resume  = "brightnessctl -r";
        }
        # 10 min: lock
        {
          timeout   = 600;
          on-timeout = "loginctl lock-session";
        }
        # ~10.5 min: display off
        {
          timeout   = 630;
          on-timeout = "${wlopm} --off '*'";
          on-resume  = "${wlopm} --on '*'";
        }
        # 30 min: suspend (before_sleep_cmd already locks beforehand)
        {
          timeout   = 1800;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };
}
