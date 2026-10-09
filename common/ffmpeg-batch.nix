{ pkgs }:
# Builds a command that runs one ffmpeg invocation per file given on the command
# line, writing <stem><suffix> next to the source. On a terminal, ffmpeg's
# -progress output is rendered as a bar with percent, speed and ETA; otherwise
# ffmpeg's default status line is kept so logs stay readable.
{
  name,
  suffix,
  description,
  inputArgs ? "",
  outputArgs,
}:
pkgs.writeShellScriptBin name ''
  set -u
  FF=${pkgs.ffmpeg}/bin/ffmpeg
  FP=${pkgs.ffmpeg}/bin/ffprobe

  if [ "$#" -eq 0 ]; then
    echo "Usage: ${name} <video> [<video>...]" >&2
    echo "" >&2
    echo ${pkgs.lib.escapeShellArg description} >&2
    echo "Output: <name>${suffix}" >&2
    exit 1
  fi

  run_ffmpeg() {
    "$FF" -hide_banner "$@" \
      ${inputArgs} -i "$src" \
      ${outputArgs} \
      -y "$out"
  }

  count=$#
  idx=0
  status=0
  for src in "$@"; do
    idx=$((idx + 1))
    if [ ! -f "$src" ]; then
      printf '\033[31m✗ not found:\033[0m %s\n' "$src" >&2
      status=1
      continue
    fi

    dir=$(dirname -- "$src")
    base=$(basename -- "$src")
    stem=''${base%.*}
    out="$dir/''${stem}${suffix}"
    outbase=$(basename -- "$out")

    dur=$("$FP" -v error -show_entries format=duration \
            -of default=nk=1:nw=1 -- "$src" 2>/dev/null || true)
    dur_us=$(awk -v d="$dur" 'BEGIN { printf "%d", (d == "" || d == "N/A") ? 0 : d * 1000000 }')

    printf '\033[1m[%d/%d]\033[0m %s \033[2m→\033[0m %s\n' "$idx" "$count" "$base" "$outbase" >&2

    if [ -t 2 ]; then
      run_ffmpeg -loglevel error -nostats -progress pipe:1 \
        | awk -v dur="$dur_us" -v W=36 '
            function hms(s,   h, m) {
              if (s < 0) s = 0
              h = int(s / 3600); s -= h * 3600
              m = int(s / 60);   s = int(s - m * 60)
              return h > 0 ? sprintf("%d:%02d:%02d", h, m, s) : sprintf("%02d:%02d", m, s)
            }
            /^out_time_us=/ { split($0, a, "="); t = a[2] + 0 }
            /^speed=/       { v = $0; sub(/^speed=/, "", v); sub(/x$/, "", v); spd = (v == "N/A") ? 0 : v + 0 }
            /^progress=/ {
              done = ($0 ~ /end/)
              if (done && dur > 0) t = dur
              spdstr = (spd > 0) ? sprintf("%.2fx", spd) : "—"
              if (dur > 0) {
                pct = t / dur * 100; if (pct > 100) pct = 100
                fill = int(pct / 100 * W)
                bar = ""
                for (i = 0; i < fill; i++) bar = bar "█"
                for (i = fill; i < W;    i++) bar = bar "░"
                eta = (spd > 0) ? (dur - t) / 1000000 / spd : -1
                etastr = (eta >= 0) ? hms(eta) : "—"
                printf "\r\033[2K\033[32m%s\033[0m %5.1f%%  \033[36m%7s\033[0m  ETA \033[33m%s\033[0m", bar, pct, spdstr, etastr > "/dev/stderr"
              } else {
                printf "\r\033[2K  %s processed  \033[36m%s\033[0m", hms(t / 1000000), spdstr > "/dev/stderr"
              }
              if (done) printf "\n" > "/dev/stderr"
              fflush()
            }
          '
      rc=''${PIPESTATUS[0]}
    else
      run_ffmpeg
      rc=$?
    fi

    if [ "$rc" -eq 0 ]; then
      sz=$(du -h -- "$out" 2>/dev/null | cut -f1)
      printf '\033[32m✓\033[0m %s \033[2m(%s)\033[0m\n\n' "$outbase" "$sz" >&2
    else
      printf '\033[31m✗ ffmpeg failed (rc=%s) for\033[0m %s\n\n' "$rc" "$src" >&2
      status=1
    fi
  done
  exit "$status"
''
