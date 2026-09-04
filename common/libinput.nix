{ ... }:
{
  # libinput debounces every mouse button by default (25 ms) to hide worn
  # switches; that adds latency and swallows fast double-clicks. The quirk name
  # is misleading: EVDEV_MODEL_BOUNCING_KEYS does not enable debouncing, it
  # tells libinput the device handles it itself and *disables* its own filter.
  environment.etc."libinput/local-overrides.quirks".text = ''
    [Never Debounce]
    MatchUdevType=mouse
    ModelBouncingKeys=1
  '';
}
