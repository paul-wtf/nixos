# macbook (nix-darwin)

## Window manager: yabai + skhd (BSP = dwindle)

The WM is **yabai** (real binary space partitioning, equivalent to Hyprland's dwindle) with
**skhd** as the hotkey daemon and **JankyBorders** for the window border.

## Initial setup (order matters!)

1. **Partially disable SIP** (needed for yabai's Scripting Addition = space control):
   - Reboot into recoveryOS: shut down the Mac, then hold the power button until
     "Loading startup options" appears → **Options** → open Terminal.
   - Run there: `csrutil enable --without fs --without debug --without nvram`
     (yabai's recommended partial disable; NOT a full `csrutil disable`).
   - Reboot.
2. `sudo darwin-rebuild switch --flake .#macbook` (or, the very first time,
   `sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#macbook`).
3. Grant the **Accessibility permission** for **yabai** AND **skhd**
   (System Settings → Privacy & Security → Accessibility). The entries are
   `/usr/local/libexec/nix-codesign/yabai` and `.../skhd`, not store paths;
   see "Stable Accessibility grant" below.
4. Restart yabai/skhd (`launchctl kickstart -k gui/$(id -u)/org.nixos.yabai`
   and `... org.nixos.skhd` — NOT `yabai --restart-service`, which manages yabai's
   own launchd plists and starts a second instance next to the org.nixos.* services)
   or log out and back in. The 10 spaces are created automatically when yabai starts.

## Stable Accessibility grant

TCC ties the Accessibility grant of a bare binary to its path and its code
signature requirement. Nix store paths change with every flake update that
touches the build inputs, and yabai's ad-hoc cdhash often changes too, so a
grant on the store binary is lost after almost every update.

`codesign.nix` therefore copies yabai and skhd to `/usr/local/libexec/nix-codesign/`
during activation and signs them with a local self-signed certificate; the
launchd agents run those copies (`Program`). The grant then matches
`identifier yabai and certificate leaf = H"…"` and survives rebuilds.

- The certificate and its keychain are created on the first activation in
  `/var/db/nix-codesign/` (root only). If that directory is deleted, the next
  switch creates a new certificate and the grant has to be given once more.
- `sudo yabai --load-sa` keeps using the store binary, because nix-darwin's
  sudoers rule pins that binary's sha256.
- `ps` still shows the store path. That is only argv[0]; the executable is the
  signed copy (`launchctl print gui/$(id -u)/org.nixos.yabai | grep program`).

## After macOS updates

A macOS update can unload the Scripting Addition. Then run once:
`sudo yabai --load-sa` (passwordless thanks to nix-darwin) or restart yabai.
Rarely, a bigger update also reverts the partial SIP disable → repeat step 1.

## Manual / non-declarative items
- SIP partial disable (recoveryOS, security boundary — not automatable).
- Accessibility permission for yabai + skhd (one-time).
- Launcher: **Raycast** (hotkey `alt+shift-return` via skhd → `open raycast://`).
  Not declarable (Raycast config is GUI/cloud). Sol/Ueli were considered:
  Ueli is deprecated (Gatekeeper), Sol would be the alternative — staying with Raycast for now.

## Keybinds (modifier = Alt ⌥)
- `alt-return` kitty · `alt+shift-q` close · `alt-f` fullscreen · `alt-v` float
- `alt-j` toggle split direction (dwindle) · `alt-e` Finder · `alt+shift-return` Raycast
- `alt-←/→/↑/↓` focus · `alt-1..0` space 1..10 · `alt+shift-1..0` window → space
- Mouse: `alt`+left-drag = move, `alt`+right-drag = resize

## Troubleshooting

**Border flickers / disappears periodically (~100ms every few seconds):**
A second borders instance is running (typically: a Homebrew leftover from an earlier
manual yabai attempt) that collides with the nix `org.nixos.jankyborders` service —
the nix service then flaps (`launchctl print gui/$(id -u)/org.nixos.jankyborders`
shows `state = spawn scheduled`, `runs` keeps increasing). Check:
```
launchctl list | grep -iE 'yabai|skhd|border'   # only org.nixos.* may be running
brew list | grep -iE 'yabai|skhd|borders'        # no Homebrew WM tools
```
Remove the Homebrew leftover: `brew uninstall borders` and
`rm ~/Library/LaunchAgents/homebrew.mxcl.borders.plist`, then
`launchctl kickstart -k gui/$(id -u)/org.nixos.jankyborders`.
As a general rule: the WM stack (yabai/skhd/borders) goes through nix ONLY, never additionally via Homebrew.

## Still open
Cross-check the full NixOS build on a Linux machine/CI (on the Mac, catppuccin's IFD blocks it).
