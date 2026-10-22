{ pkgs, lib, ... }:
let
  alpha = "alsa_output.usb-D_A_D_A_Alpha-00.analog-stereo";

  # oratory1990 measurement, post-2020 earpads, AutoEq Harman over-ear target.
  preamp = -6.6;
  bass = 7;
  filters = [
    { label = "bq_lowshelf"; freq = 105; q = 0.70; gain = 8.9; }
    { label = "bq_peaking"; freq = 56; q = 0.40; gain = -4.5; }
    { label = "bq_peaking"; freq = 971; q = 1.62; gain = -1.8; }
    { label = "bq_peaking"; freq = 2115; q = 2.21; gain = 2.1; }
    { label = "bq_peaking"; freq = 8270; q = 0.96; gain = 1.4; }
    { label = "bq_highshelf"; freq = 10000; q = 0.70; gain = -3.1; }
    { label = "bq_peaking"; freq = 246; q = 1.21; gain = -0.6; }
    { label = "bq_peaking"; freq = 128; q = 1.44; gain = 0.7; }
    { label = "bq_peaking"; freq = 59; q = 2.26; gain = -0.6; }
    { label = "bq_peaking"; freq = 35; q = 1.56; gain = 0.2; }
  ];

  # A high shelf at 0 Hz is a flat gain.
  stages =
    [ { name = "preamp"; label = "bq_highshelf"; freq = 0; q = 1.0; gain = preamp - bass; } ]
    ++ lib.imap1 (i: f: f // { name = "f${toString i}"; }) filters
    ++ [ { name = "bass"; label = "bq_lowshelf"; freq = 105; q = 0.70; gain = bass; } ];

  node = s: ''
    { type = builtin name = ${s.name} label = ${s.label} control = { "Freq" = ${toString s.freq} "Q" = ${toString s.q} "Gain" = ${toString s.gain} } }'';
  link = a: b: ''{ output = "${a.name}:Out" input = "${b.name}:In" }'';

  conf = pkgs.writeText "sundara-eq.conf" ''
    context.properties = { log.level = 0 }
    context.spa-libs = {
        audio.convert.* = audioconvert/libspa-audioconvert
        support.*       = support/libspa-support
    }
    context.modules = [
        { name = libpipewire-module-rt flags = [ ifexists nofail ] }
        { name = libpipewire-module-protocol-native }
        { name = libpipewire-module-client-node }
        { name = libpipewire-module-adapter }
        { name = libpipewire-module-filter-chain
            args = {
                node.description = "Sundara EQ"
                media.name       = "Sundara EQ"
                filter.graph = {
                    nodes = [
                        ${lib.concatStringsSep "\n" (map node stages)}
                    ]
                    links = [
                        ${lib.concatStringsSep "\n" (lib.zipListsWith link stages (lib.tail stages))}
                    ]
                }
                audio.channels = 2
                audio.position = [ FL FR ]
                capture.props = {
                    node.name   = "sundara_eq"
                    media.class = "Audio/Sink"
                }
                playback.props = {
                    node.name     = "sundara_eq.out"
                    node.passive  = true
                    target.object = "${alpha}"
                }
            }
        }
    ]
  '';

  sundara-eq = pkgs.writeShellApplication {
    name = "sundara-eq";
    runtimeInputs = [ pkgs.pipewire pkgs.jq pkgs.coreutils pkgs.gawk pkgs.systemd ];
    text = ''
      alpha=${alpha}
      unit=sundara-eq

      usage() {
        echo "usage: sundara-eq on [bass-dB] | off | bass <dB> | status" >&2
        exit 2
      }

      alpha_streams() {
        pw-dump | jq -r --arg alpha "$alpha" '.[]
          | select(.type == "PipeWire:Interface:Node")
          | .info.props
          | select(."media.class" == "Stream/Output/Audio")
          | select((."node.target" // ."target.object") == $alpha)
          | select(."node.name" != "sundara_eq.out")
          | ."object.id"'
      }

      eq_id() {
        pw-dump | jq -r '.[] | select(.info.props."node.name"? == "sundara_eq") | .id'
      }

      set_bass() {
        local id gain pre
        id=$(eq_id)
        [ -n "$id" ] || { echo "Sundara EQ is not running" >&2; exit 1; }
        gain=$1
        pre=$(awk -v g="$gain" 'BEGIN { printf "%.2f", ${toString preamp} - (g > 0 ? g : 0) }')
        pw-cli set-param "$id" Props "{ params = [ \"bass:Gain\" $gain \"preamp:Gain\" $pre ] }" >/dev/null
        echo "extra bass shelf: $gain dB at 105 Hz, preamp: $pre dB"
      }

      case "''${1:-}" in
        on)
          if ! systemctl --user -q is-active "$unit"; then
            systemd-run --user --collect -q --unit="$unit" pipewire -c ${conf}
          fi
          for _ in $(seq 50); do
            [ -n "$(eq_id)" ] && break
            sleep 0.1
          done
          for id in $(alpha_streams); do
            pw-metadata -n default "$id" target.object sundara_eq >/dev/null
          done
          set_bass "''${2:-${toString bass}}"
          ;;
        off)
          for id in $(alpha_streams); do
            pw-metadata -n default -d "$id" target.object >/dev/null
          done
          systemctl --user stop "$unit" 2>/dev/null || true
          echo "Sundara EQ off"
          ;;
        bass)
          [ $# -eq 2 ] || usage
          set_bass "$2"
          ;;
        status)
          id=$(eq_id)
          if [ -z "$id" ]; then
            echo "off"
            exit 0
          fi
          pw-dump "$id" | jq -r '.[0].info.params.Props[] | select(.params) | .params
            | [range(0; length; 2) as $i | {k: .[$i], v: .[$i + 1]}]
            | .[] | select(.k | test("^(preamp|bass):Gain$")) | "\(.k) = \(.v) dB"'
          pw-link -l | grep -A4 '^sundara_eq:playback_FL' || true
          ;;
        *) usage ;;
      esac
    '';
  };
in
{
  home.packages = [ sundara-eq ];
}
