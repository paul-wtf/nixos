{ pkgs, lib, ... }:
let
  version = "2.2.5";
  addonVersion = "0.2.2";

  # The bundled RenoDX add-on drives NGX feature 18 through the driver, which
  # under Proton either crashes the game or presents a black frame. This one
  # hooks the game's NGX calls directly instead. Its forwarder has to sit
  # beside the game exe -- the add-on looks for it by that exact name there.
  linuxAddon = pkgs.fetchurl {
    url = "https://github.com/NapXDD/addon-dlssnr-linux/releases/download/v${addonVersion}/dlssnr-linux.addon64";
    hash = "sha256-vWKuN6VaDotGmDAd2GI3jmFFSs9OEIO42gGPcCc7tqc=";
  };
  linuxForwarder = pkgs.fetchurl {
    url = "https://github.com/NapXDD/addon-dlssnr-linux/releases/download/v${addonVersion}/nvngx.dll_nrfwd.dll";
    hash = "sha256-lAFQVF1+FDnYHQcR/FlrRNP1uBARaL+72PK2LrdyMdM=";
  };

  dlss5-swapper = pkgs.stdenv.mkDerivation {
    pname = "dlss5-swapper";
    inherit version;

    # Windows-only releases. The git repo cannot be built instead: its
    # collect-payload.js picks the DLSS files off the author's own disk, so
    # nvngx_dlssnr.dll and the ReShade setup exist only inside this installer.
    src = pkgs.fetchurl {
      url = "https://github.com/rakanki911/DLSS5-Swapper/releases/download/v${version}/DLSS5-Swapper-${version}-portable.exe";
      hash = "sha256-kj07kT5g3qxftJQWzXXkCdoDmIFNWYOXIb2Gc6iHz2M=";
    };

    nativeBuildInputs = with pkgs; [ p7zip asar copyDesktopItems makeWrapper ];

    unpackPhase = ''
      runHook preUnpack
      7z x -bso0 $src '$PLUGINSDIR/app-64.7z'
      7z x -bso0 '$PLUGINSDIR/app-64.7z'
      runHook postUnpack
    '';

    desktopItems = [
      (pkgs.makeDesktopItem {
        name = "dlss5-swapper";
        desktopName = "DLSS 5 Swapper";
        comment = "Install and manage DLSS 5 neural rendering for games";
        exec = "dlss5-swapper";
        icon = "dlss5-swapper";
        categories = [ "Game" "Utility" ];
      })
    ];

    installPhase = ''
      runHook preInstall

      app=$out/share/dlss5-swapper/app
      asar extract resources/app.asar $app
      cp -r resources/payload $app/payload
      # Run from source rather than as a packaged app, so the paths main.js
      # probes are the ones relative to main.js.
      install -Dm644 resources/overlay/dlss5-lab-overlay.addon64 \
        $app/dist/overlay/dlss5-lab-overlay.addon64

      # Both files are registered as add-ons in the app: the one named like the
      # bundled build replaces it, the forwarder rides along as a companion and
      # is copied beside the game exe, which is the only place it is looked for.
      # The app stores absolute paths in its own state and rejects symlinks
      # (overlays.js lstats and refuses them), so a store path would break on
      # the next update and a link would never be accepted. Copying into $HOME
      # on every start keeps one stable path that stays current.
      makeWrapper ${lib.getExe pkgs.electron} $out/bin/dlss5-swapper \
        --add-flags $app \
        --run 'data="''${XDG_DATA_HOME:-$HOME/.local/share}/dlss5-swapper"' \
        --run 'install -Dm644 ${linuxAddon} "$data/addons/renodx-dlss.addon64"' \
        --run 'install -Dm644 ${linuxForwarder} "$data/addons/nvngx.dll_nrfwd.dll"' \
        --run 'cd "$data"'

      install -Dm644 $app/assets/logo.png $out/share/pixmaps/dlss5-swapper.png
      install -Dm644 ${linuxAddon} $out/share/dlss5-swapper/renodx-dlss.addon64
      install -Dm644 ${linuxForwarder} $out/share/dlss5-swapper/nvngx.dll_nrfwd.dll

      runHook postInstall
    '';

    meta = {
      description = "DLSS 5 neural rendering for games, with the Linux add-on in place of the bundled one";
      homepage = "https://github.com/rakanki911/DLSS5-Swapper";
      license = lib.licenses.unfree;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      platforms = [ "x86_64-linux" ];
      mainProgram = "dlss5-swapper";
    };
  };

  # Repairs a game the app installed before both add-ons were registered with
  # it, and drops the lab overlay, which the app reinstalls every time.
  dlss5-swapper-linux-addon = pkgs.writeShellApplication {
    name = "dlss5-swapper-linux-addon";
    runtimeInputs = with pkgs; [ jq ];
    text = ''
      shopt -s nullglob
      games=( "$@" )
      if [ ''${#games[@]} -eq 0 ]; then
        while IFS= read -r -d "" manifest; do
          games+=( "$(dirname "$(dirname "$manifest")")" )
        done < <(find "$HOME/.local/share/Steam/steamapps/common" -maxdepth 3 \
          -name manifest.json -path '*/_DLSS5_Backup/*' -print0)
      fi

      for game in "''${games[@]}"; do
        manifest=$game/_DLSS5_Backup/manifest.json
        if [ ! -f "$manifest" ]; then echo "skip (no manifest): $game"; continue; fi
        exedir=$game/$(dirname "$(jq -r .game.exe "$manifest")")
        echo "== $game"

        install -Dm644 ${linuxForwarder} "$exedir/nvngx.dll_nrfwd.dll"

        # Belongs to the RenoDX route and was never tried alongside this
        # add-on; the app reinstalls it with every install.
        rm -f "$exedir"/dlss5-lab-overlay-*.addon64

        # Only needed when the add-on is not switched on in the app: there the
        # same file name makes it replace the bundled build by itself.
        if ! cmp -s "$exedir/renodx-dlss.addon64" ${linuxAddon}; then
          install -Dm644 ${linuxAddon} "$exedir/renodx-dlss.addon64"
          echo "   replaced the bundled RenoDX build"
        fi
      done
    '';
  };
in
{
  environment.systemPackages = [ dlss5-swapper dlss5-swapper-linux-addon ];
}
