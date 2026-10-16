{ pkgs, ... }:
let
  frameaverage = import ../../common/frameaverage-package.nix { inherit pkgs; };

  upload = pkgs.writeShellApplication {
    name = "clips-upload";
    runtimeInputs = [
      frameaverage
      pkgs.coreutils
      pkgs.curl
      pkgs.findutils
      pkgs.gnugrep
      pkgs.inotify-tools
      pkgs.libnotify
      pkgs.psmisc
    ];
    text = ''
      clips="$HOME/Videos/Clips"
      token_file="$HOME/.config/fireshare/upload-token"
      state="$STATE_DIRECTORY/uploaded"
      resp="$STATE_DIRECTORY/response"
      url=https://clips.paul.wtf/api/upload/token
      suffix=_60fps.mp4

      if [ ! -r "$token_file" ]; then
        echo "No Fireshare upload token at $token_file" >&2
        exit 1
      fi

      notify() {
        echo "$1: $2" >&2
        notify-send -a clips-upload "$1" "$2" || true
      }

      # Clips that predate this service were already rsynced and stay as they are.
      if [ ! -e "$state" ]; then
        find "$clips" -type f -name '*.mp4' > "$state"
      fi

      # gpu-screen-recorder may close and reopen a clip while muxing it.
      settle() {
        local prev=-1 size
        while [ -f "$1" ]; do
          size=$(stat -c %s -- "$1")
          if [ "$size" = "$prev" ] && ! fuser -s -- "$1" 2>/dev/null; then
            return 0
          fi
          prev=$size
          sleep 2
        done
        return 1
      }

      upload() {
        local file=$1 title=$2 folder=$3 code attempt
        local args=(--form-string "title=$title")
        if [ -n "$folder" ]; then
          args+=(--form-string "folder=$folder")
        fi
        for attempt in 1 2 3 4 5; do
          code=$(printf 'header = "Authorization: Bearer %s"\n' "$(< "$token_file")" \
            | curl -sS -K - -o "$resp" -w '%{http_code}' \
                -F "file=@\"$file\";type=video/mp4" "''${args[@]}" "$url") || code=000
          case $code in
            201 | 409)
              echo "$file" >> "$state"
              echo "Uploaded $file ($code)"
              return 0
              ;;
            400 | 401 | 403 | 413)
              notify "Clip upload rejected ($code)" "$(basename -- "$file"): $(head -c 300 "$resp" 2>/dev/null)"
              return 1
              ;;
          esac
          echo "Upload of $file failed ($code), attempt $attempt" >&2
          sleep $((attempt * 30))
        done
        notify "Clip upload failed" "$(basename -- "$file") stays queued until the next clip"
        return 1
      }

      handle() {
        local file=$1 rel dir folder="" stem out
        rel=''${file#"$clips"/}
        dir=$(dirname -- "$rel")
        if [ "$dir" != . ]; then
          folder=$dir
        fi
        case $file in
          *"$suffix")
            stem=$(basename -- "$file" "$suffix")
            upload "$file" "$stem" "$folder"
            return
            ;;
        esac

        settle "$file" || return 0
        stem=$(basename -- "$file" .mp4)
        out=''${file%.mp4}$suffix
        if ! frameaverage "$file" < /dev/null 2>&1 | tr '\r' '\n' | { grep -av '^frame=' || true; } || [ ! -s "$out" ]; then
          notify "frameaverage failed" "$rel is kept and not uploaded"
          echo "$file" >> "$state"
          return 1
        fi
        rm -- "$file"
        upload "$out" "$stem" "$folder"
      }

      scan() {
        local file
        find "$clips" -type f -name '*.mp4' | sort | while IFS= read -r file; do
          grep -qxF -- "$file" "$state" || handle "$file" || true
        done
      }

      scan
      inotifywait -m -r -q -e close_write -e moved_to --format '%w%f' "$clips" \
        | while IFS= read -r file; do
            case $file in
              *"$suffix") ;;
              *.mp4) scan ;;
            esac
          done
    '';
  };
in
{
  home-manager.users.paul.systemd.user.services.clips-upload = {
    Unit.Description = "Frame-average new gpu-screen-recorder clips and upload them to Fireshare";
    Service = {
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/Videos/Clips";
      ExecStart = "${upload}/bin/clips-upload";
      StateDirectory = "clips-upload";
      Restart = "on-failure";
      RestartSec = "1min";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
