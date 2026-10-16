#!/usr/bin/env bash
# Updates every flake input, then every package pinned outside the flake (hosts/*/*-update.sh).
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
nix --extra-experimental-features 'nix-command flakes' flake update
for script in hosts/*/*-update.sh; do
  "$script"
done
