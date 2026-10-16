#!/usr/bin/env bash
# Bumps tiny4linux.json to the latest GitHub release, including the cargo vendor hash.
set -euo pipefail

dir=$(dirname "$(readlink -f "$0")")
json="$dir/tiny4linux.json"
lock="$dir/../../flake.lock"

latest=$(curl -fsSL https://api.github.com/repos/OpenFoxes/Tiny4Linux/releases/latest | jq -r '.tag_name // empty')
[[ -n $latest ]] || { echo "tiny4linux: no release found" >&2; exit 1; }
version=${latest#v}

current=$(jq -r .version "$json")
if [[ $version == "$current" ]]; then
  echo "tiny4linux: already at $current"
  exit 0
fi

hash=$(nix --extra-experimental-features 'nix-command flakes' flake prefetch --json \
  "github:OpenFoxes/Tiny4Linux/$latest" | jq -r .hash)

# The vendor hash only exists as the "got:" line of a build against an empty hash.
nixpkgs=$(jq -r '.nodes.nixpkgs.locked | "github:\(.owner)/\(.repo)/\(.rev)"' "$lock")
cargoHash=$(nix --extra-experimental-features 'nix-command flakes' build --impure --no-link --expr "
  let pkgs = (builtins.getFlake \"$nixpkgs\").legacyPackages.x86_64-linux; in
  pkgs.rustPlatform.fetchCargoVendor {
    src = pkgs.fetchFromGitHub { owner = \"OpenFoxes\"; repo = \"Tiny4Linux\"; tag = \"$latest\"; hash = \"$hash\"; };
    hash = \"\";
  }" 2>&1 | sed -nE 's/^ *got: *(sha256-[^ ]+)$/\1/p' || true)
[[ -n $cargoHash ]] || { echo "tiny4linux: could not determine cargoHash" >&2; exit 1; }

jq -n --arg v "$version" --arg h "$hash" --arg c "$cargoHash" \
  '{version: $v, hash: $h, cargoHash: $c}' > "$json"
echo "tiny4linux: $current -> $version"
