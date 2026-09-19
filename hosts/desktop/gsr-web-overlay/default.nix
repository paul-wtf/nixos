{ pkgs, lib, gsr-ui-nix, ... }:
let
  # Tidal media widget served by tidal-hifi's streamer tools.
  url = "http://localhost:2403/streamer-tools/widget5";
  shm = "gsr-web-overlay.shm";

  gsr = gsr-ui-nix.packages.${pkgs.stdenv.hostPlatform.system}.gpu-screen-recorder.overrideAttrs (old: {
    # 6.0.2 builds the plugin color conversion without the external-texture
    # shader, so every plugin aborts on an assertion under KMS capture on NVIDIA.
    patches = (old.patches or [ ]) ++ [ ./plugin-external-texture.patch ];
  });

  plugin = pkgs.stdenv.mkDerivation {
    pname = "gsr-web-overlay-plugin";
    version = "1";
    src = ./plugin.c;
    dontUnpack = true;
    buildInputs = [ gsr pkgs.libGL ];
    buildPhase = ''
      runHook preBuild
      $CC -O2 -Wall -Wextra -shared -fPIC -o gsr-web-overlay.so $src
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 gsr-web-overlay.so $out/lib/gsr-web-overlay.so
      runHook postInstall
    '';
  };

  feed = pkgs.writers.writePython3Bin "gsr-web-overlay-feed" {
    libraries = with pkgs.python3Packages; [ websockets pillow ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./feed.py);

  # gsr-ui has no plugin setting and finds the recorder through PATH, so this
  # shadows it there. Only capture runs get the plugin: gsr-ui also calls the
  # recorder for --list-* queries, which take no further arguments.
  recorder = pkgs.writeShellScriptBin "gpu-screen-recorder" ''
    record=0 hdr=0 prev=
    for arg in "$@"; do
      case "$prev" in
        -w) record=1 ;;
        -k) case "$arg" in *_hdr) hdr=1 ;; esac ;;
      esac
      prev=$arg
    done
    if [ "$record" = 1 ] && [ -n "''${XDG_RUNTIME_DIR:-}" ]; then
      export GSR_WEB_OVERLAY_SHM="$XDG_RUNTIME_DIR/${shm}"
      export GSR_WEB_OVERLAY_HDR=$hdr
      # sdr_max_luminance in hyprland-monitors.nix
      export GSR_WEB_OVERLAY_SDR_NITS=250
      exec ${gsr}/bin/gpu-screen-recorder "$@" -p ${plugin}/lib/gsr-web-overlay.so
    fi
    exec ${gsr}/bin/gpu-screen-recorder "$@"
  '';
in
{
  programs.gpu-screen-recorder.package = lib.mkForce gsr;
  environment.systemPackages = [ (lib.hiPrio recorder) ];

  home-manager.users.paul.systemd.user.services.gsr-web-overlay = {
    Unit.Description = "Render the Tidal widget for the gpu-screen-recorder overlay";
    Service = {
      ExecStart = "${feed}/bin/gsr-web-overlay-feed --shm %t/${shm} --profile %t/gsr-web-overlay-chromium --scale 1.5 --chromium ${lib.getExe pkgs.chromium} ${url}";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
