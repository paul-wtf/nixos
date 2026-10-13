{ ... }:
let
  # Catppuccin Mocha, matching the Starship powerline scheme (starship.nix):
  # system block teal, hardware block sky, dimmed parts overlay0.
  teal = "38;2;148;226;213";
  sky = "38;2;137;220;235";
  dim = "38;2;108;112;134";
  m = type: key: keyColor: { inherit type key keyColor; };
in
{
  # hyfetch (backend = "fastfetch") only provides the logo; selection and colors
  # of the info lines come from this config (~/.config/fastfetch/config.jsonc).
  # enable installs the binary on both platforms.
  programs.fastfetch = {
    enable = true;
    settings = {
      display = {
        separator = " ";
        key.width = 10;
      };
      modules = [
        {
          type = "title";
          color = {
            user = teal;
            at = dim;
            host = sky;
          };
        }
        {
          type = "custom";
          format = "─────────────────────";
          outputColor = dim;
        }
        (m "os" "OS" teal)
        # Only the board/device name, without the firmware version string after it
        ((m "host" "Host" teal) // { format = "{name}"; })
        (m "kernel" "Kernel" teal)
        (m "uptime" "Uptime" teal)
        (m "packages" "Packages" teal)
        (m "shell" "Shell" teal)
        (m "terminal" "Terminal" teal)
        (m "wm" "WM" teal)
        (m "cpu" "CPU" sky)
        (m "gpu" "GPU" sky)
        (m "memory" "RAM" sky)
        (m "disk" "Disk" sky)
        (m "display" "Display" sky)
        { type = "break"; }
        {
          type = "colors";
          symbol = "circle";
        }
      ];
    };
  };
}
