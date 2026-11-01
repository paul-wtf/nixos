{ pkgs, ... }:
let
  # The launcher binds the licence to a HWID that Windows code computes from
  # inside the Wine prefix. Everything it can see is pinned: the final
  # Wine-GE release (the project is archived), a fixed JDK build and one
  # prefix that nothing recreates or upgrades.
  wine-ge = pkgs.fetchzip {
    url = "https://github.com/GloriousEggroll/wine-ge-custom/releases/download/GE-Proton8-26/wine-lutris-GE-Proton8-26-x86_64.tar.xz";
    hash = "sha256-qVqmq57tNLqWJTs83lLuzKDRRM2lC5SChpQ0NkdaDgg=";
  };

  jdk-win = pkgs.fetchzip {
    url = "https://cdn.azul.com/zulu/bin/zulu8.72.0.17-ca-fx-jdk8.0.382-win_x64.zip";
    hash = "sha256-Vh1kA0uiPaLLqhggBF2NLxAjOcoNBKF/xWg7FhHuzbk=";
  };

  assetIndex = pkgs.fetchurl {
    url = "https://launchermeta.mojang.com/v1/packages/f6ad102bcaa53b1a58358f16e376d548d44933ec/1.8.json";
    sha1 = "f6ad102bcaa53b1a58358f16e376d548d44933ec";
  };

  assetDownloads = pkgs.runCommand "augustus-assets-1.8.curl" { nativeBuildInputs = [ pkgs.jq ]; } ''
    jq -r '.objects[].hash | "url = \"https://resources.download.minecraft.net/\(.[:2])/\(.)\"\noutput = \"objects/\(.[:2])/\(.)\""' ${assetIndex} > $out
  '';

  launch = pkgs.writeShellScript "augustus-launch" ''
    set -eu
    dir="''${XDG_DATA_HOME:-$HOME/.local/share}/augustus"
    jar="$dir/Launcher.jar"
    if [ ! -f "$jar" ]; then
      echo "augustus: put the Augustus .jar launcher at $jar" >&2
      exit 1
    fi
    export WINEPREFIX="$dir/prefix"
    export WINEARCH=win64
    export WINEDEBUG=-all
    export WINEDLLOVERRIDES="mscoree,mshtml="
    if [ ! -d "$WINEPREFIX" ]; then
      ${wine-ge}/bin/wineboot -i
      ${wine-ge}/bin/wineserver -w
      # JavaFX opens the system font (Tahoma under Wine) only from
      # C:\windows\Fonts, which Wine leaves empty.
      install -m644 -t "$WINEPREFIX/drive_c/windows/Fonts" \
        ${wine-ge}/share/wine/fonts/tahoma.ttf ${wine-ge}/share/wine/fonts/tahomabd.ttf
    fi
    # The client expects the vanilla 1.8 assets (sounds, languages) that only
    # Mojang's own launcher downloads.
    assets="$WINEPREFIX/drive_c/users/$USER/AppData/Roaming/.minecraft/assets"
    if [ ! -f "$assets/indexes/1.8.json" ]; then
      mkdir -p "$assets"
      (cd "$assets" && ${pkgs.curl}/bin/curl -fsS --parallel --create-dirs --skip-existing -K ${assetDownloads})
      install -Dm644 ${assetIndex} "$assets/indexes/1.8.json"
    fi
    cd "$dir"
    exec ${wine-ge}/bin/wine ${jdk-win}/bin/javaw.exe -jar "$jar" "$@"
  '';

  desktopItem = pkgs.makeDesktopItem {
    name = "augustus";
    desktopName = "Augustus";
    genericName = "Minecraft client";
    exec = "augustus";
    categories = [ "Game" ];
  };

  augustus = pkgs.buildFHSEnv {
    pname = "augustus";
    version = "GE-Proton8-26";

    multiArch = true;
    targetPkgs = pkgs: with pkgs; [ xdg-utils ];
    multiPkgs = pkgs: with pkgs; [
      alsa-lib
      dbus
      fontconfig
      freetype
      glib
      gnutls
      krb5
      libGL
      libpulseaudio
      libunwind
      libx11
      libxcomposite
      libxcursor
      libxext
      libxfixes
      libxi
      libxinerama
      libxrandr
      libxrender
      libxcb
      libxkbcommon
      ncurses
      openal
      SDL2
      udev
      vulkan-loader
      zlib
    ];

    runScript = launch;

    extraInstallCommands = ''
      install -Dm644 -t $out/share/applications ${desktopItem}/share/applications/*.desktop
    '';

    meta = {
      description = "Augustus client launcher under a pinned Wine-GE";
      homepage = "https://github.com/AugustusClient/AugustusLinux";
      mainProgram = "augustus";
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  environment.systemPackages = [ augustus ];
}
