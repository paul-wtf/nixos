{ pkgs, tidaluna, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  tidalunaPkgs = import tidaluna.inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
  # TidaLuna 1.17.1-beta pins one pnpm-deps hash for both platforms, but pnpm
  # fetches platform-specific binaries, so it only matches on Linux. Drop this
  # once upstream ships a separate darwin hash.
  tidalunaInjection = tidaluna.packages.${system}.injection.overrideAttrs (old: {
    pnpmDeps = old.pnpmDeps.overrideAttrs {
      outputHash = "sha256-vYbX9AZjkXu34jGF4demR9x+Nlac6gP1gniKqED5PyQ=";
    };
  });
  tidal = tidalunaPkgs.tidal.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      if [ -f "$out/Applications/TIDAL.app/Contents/Resources/app.asar" ]; then
        mv "$out/Applications/TIDAL.app/Contents/Resources/app.asar" \
           "$out/Applications/TIDAL.app/Contents/Resources/original.asar"
      fi
      mkdir -p "$out/Applications/TIDAL.app/Contents/Resources/app/"
      cp -R ${tidalunaInjection}/* "$out/Applications/TIDAL.app/Contents/Resources/app/"
    '';
  });
in
{
  imports = [ ./yabai.nix ./homebrew.nix ./sudo-askpass.nix ];

  # Terminal/UI font for the whole system (kitty, sketchybar-style tooling).
  # Used to live in sketchybar.nix; the bar itself was removed (disabled
  # since 2026-07-06, see git history if it should ever come back).
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  networking.hostName = "paul-macbook";

  # nix-darwin requires a primary user for user-scoped options (homebrew, defaults).
  system.primaryUser = "paulweber";
  users.users.paulweber.home = "/Users/paulweber";

  # Nix is managed by Determinate Nix (its own daemon) — nix-darwin must NOT
  # manage the Nix installation as well, otherwise activation breaks
  # ("Determinate detected, aborting activation"). Flakes/nix-command are
  # globally enabled with Determinate anyway, so nix.settings is omitted here.
  nix.enable = false;

  # fish is the login shell -> nix-darwin has to set up the system integration
  # (/etc/fish + fish in /etc/shells + system PATH), otherwise the fish login shell
  # has neither nix paths nor any other system paths. (common/ with the same flag
  # is NixOS-only.)
  programs.fish.enable = true;

  # home-shared.nix (programs.vim) pulls in unfree vim plugins (asyncomplete-buffer-vim).
  # On NixOS common/programs.nix sets this system-wide; darwin needs the
  # equivalent, otherwise the Home Manager evaluation (useGlobalPkgs) fails.
  nixpkgs.config.allowUnfree = true;

  # Official TIDAL.app (aarch64-darwin, unfree) with injected TidaLuna.
  # As on Linux (common/programs.nix) taken directly from the TidaLuna flake,
  # which brings its OWN nixpkgs pin — the overlay route would instead build
  # with our nixos-unstable, whose fetchPnpmDeps no longer supports the
  # fetcherVersion=3 used by TidaLuna. The Linux wrapper
  # (--password-store=gnome-libsecret) is not needed here: Electron's safeStorage
  # automatically uses the Keychain on macOS.
  environment.systemPackages = [ tidal ];

  # System-wide dark mode.
  system.defaults.NSGlobalDomain.AppleInterfaceStyle = "Dark";

  # nix-darwin schema version. Note: darwin-rebuild only errors when
  # stateVersion is unset or outside the supported range — an outdated value is
  # accepted silently, so any bump has to be a deliberate manual change here.
  system.stateVersion = 5;
}
