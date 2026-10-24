#!/usr/bin/env bash
# Bumps horizon.json to the newest Horizon launcher release (tags launcher@X.Y.Z; the game's own vX.Y.Z
# releases are installed by the launcher at runtime).
set -euo pipefail

dir=$(dirname "$(readlink -f "$0")")
json="$dir/horizon.json"

latest=$(curl -fsSL 'https://api.github.com/repos/ludovic111/horizon/releases?per_page=100' \
  | jq -r '[.[] | select(.prerelease | not)
              | select(.tag_name | test("^launcher@[0-9]+\\.[0-9]+\\.[0-9]+$"))
              | .tag_name | ltrimstr("launcher@")]
           | sort_by(split(".") | map(tonumber)) | last // empty')
[[ -n $latest ]] || { echo "horizon: no launcher release found" >&2; exit 1; }

current=$(jq -r .version "$json")
if [[ $latest == "$current" ]]; then
  echo "horizon: already at $current"
  exit 0
fi

hash=$(nix --extra-experimental-features 'nix-command flakes' store prefetch-file --json \
  "https://github.com/ludovic111/horizon/releases/download/launcher@$latest/horizon-launcher-linux-x86_64.tar.gz" \
  | jq -r .hash)

jq -n --arg v "$latest" --arg h "$hash" '{version: $v, hash: $h}' > "$json"
echo "horizon: $current -> $latest"
