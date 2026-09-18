#!/usr/bin/env bash
# Bumps swiftpoint.json to the newest beta build linked from the Linux KB article.
set -euo pipefail

dir=$(dirname "$(readlink -f "$0")")
json="$dir/swiftpoint.json"
article="https://support.swiftpoint.com/portal/en/kb/articles/x1-control-panel-linux"
base="https://swiftpointdrivers.blob.core.windows.net/pro/beta/linux/Swiftpoint%20X1%20Control%20Panel%20"

latest=$(curl -fsSL "$article" \
  | grep -oE 'pro/beta/linux/Swiftpoint(%20| )X1(%20| )Control(%20| )Panel(%20| )[0-9.]+-[0-9a-f]+\.tar\.xz' \
  | sed -E 's/.*Panel(%20| )//; s/\.tar\.xz$//' \
  | sort -u -t- -k1,1V | tail -n1)
[[ -n $latest ]] || { echo "no Linux build found on $article" >&2; exit 1; }

version=${latest%-*}
build=${latest#*-}
current=$(jq -r .version "$json")

if [[ $version == "$current" ]]; then
  echo "swiftpoint: already at $current"
  exit 0
fi

hash=$(nix --extra-experimental-features nix-command store prefetch-file --json \
  --name "swiftpoint-x1-control-panel-$version.tar.xz" "$base$version-$build.tar.xz" \
  | jq -r .hash)

jq -n --arg v "$version" --arg b "$build" --arg h "$hash" \
  '{version: $v, build: $b, hash: $h}' > "$json"
echo "swiftpoint: $current -> $version"
