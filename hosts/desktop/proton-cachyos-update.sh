#!/usr/bin/env bash
# Bumps proton-cachyos.json to the newest dated x86_64 SLR release.
set -euo pipefail

dir=$(dirname "$(readlink -f "$0")")
json="$dir/proton-cachyos.json"

latest=$(curl -fsSL 'https://api.github.com/repos/CachyOS/proton-cachyos/releases?per_page=30' \
  | jq -r '[.[] | select(.prerelease | not)
              | select(.tag_name | test("^cachyos-[0-9.]+-[0-9]{8}-slr$"))
              | .tag_name | ltrimstr("cachyos-")]
           | sort_by(capture("-(?<d>[0-9]{8})-").d) | last // empty')
[[ -n $latest ]] || { echo "proton-cachyos: no release found" >&2; exit 1; }

current=$(jq -r .version "$json")
if [[ $latest == "$current" ]]; then
  echo "proton-cachyos: already at $current"
  exit 0
fi

hash=$(nix --extra-experimental-features 'nix-command flakes' flake prefetch --json \
  "tarball+https://github.com/CachyOS/proton-cachyos/releases/download/cachyos-$latest/proton-cachyos-$latest-x86_64.tar.xz" \
  | jq -r .hash)

jq -n --arg v "$latest" --arg h "$hash" '{version: $v, hash: $h}' > "$json"
echo "proton-cachyos: $current -> $latest"
