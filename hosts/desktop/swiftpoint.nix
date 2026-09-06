{ pkgs, lib, ... }:
let
  version = "3.1.2.0";

  # Linux is not officially supported; upstream publishes these builds as an
  # experimental side channel, so the URL carries a build hash and there is no
  # release feed to follow. Check the changelog article for newer versions:
  # https://support.swiftpoint.com/portal/en/kb/articles/swiftpoint-x1-control-panel-changelog
  icon = pkgs.fetchurl {
    url = "https://support.swiftpoint.com/portal/api/publicImages/236657000020283222?portalId=edbsn0d3aa90196a4e3b6b39dfa53f41ea57346e362747d42eef1744d58b0281647e9";
    hash = "sha256-pxF+h6v1aTJf5iV9XsXnBDsVbQb+69msIr1U8YG5Nvk=";
    name = "swiftpoint-x1-control-panel.png";
  };

  swiftpoint-x1-control-panel = pkgs.stdenv.mkDerivation {
    pname = "swiftpoint-x1-control-panel";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://swiftpointdrivers.blob.core.windows.net/pro/beta/linux/Swiftpoint%20X1%20Control%20Panel%20${version}-75bd9042.tar.xz";
      hash = "sha256-AKAKmOL8jg6jKsWzTLAI/zmhd+keKPwpVRBw3tNxsEk=";
    };

    sourceRoot = "Swiftpoint X1 Control Panel ${version}";

    nativeBuildInputs = with pkgs; [ autoPatchelfHook copyDesktopItems makeWrapper ];

    # Qt itself is bundled under lib/ (6.9.1) -- mixing in the nixpkgs Qt would
    # pull a newer libQt6Core into the same process, so only the libraries the
    # bundle expects from the system are listed here.
    buildInputs = with pkgs; [
      dbus
      fontconfig
      freetype
      glib
      libGL
      libkrb5
      libxkbcommon
      stdenv.cc.cc.lib
      systemdLibs
      wayland
      zlib
      zstd
      xorg.libX11
      xorg.libxcb
      xorg.xcbutilimage
      xorg.xcbutilkeysyms
      xorg.xcbutilrenderutil
      xorg.xcbutilwm
    ];

    # Leftovers from the Qt5 era of this app that upstream never removed. Qt6
    # refuses to load them at runtime, and autoPatchelf would fail on their
    # missing Qt5 libraries. The two Qt6 plugins go for the opposite reason:
    # they need libQt6Svg / libQt6WaylandEglClientHwIntegration, neither of
    # which is in the tarball. Qt falls back to bradient and shm.
    postPatch = ''
      rm -r plugins/bearer plugins/iconengines plugins/imageformats \
            plugins/platforminputcontexts plugins/xcbglintegrations
      rm plugins/wayland-decoration-client/libadwaita.so \
         plugins/wayland-graphics-integration-client/libqt-plugin-wayland-egl.so
    '';

    desktopItems = [
      (pkgs.makeDesktopItem {
        name = "swiftpoint-x1-control-panel";
        desktopName = "Swiftpoint X1 Control Panel";
        comment = "Configure Swiftpoint mice";
        exec = "swiftpoint-x1-control-panel";
        icon = "swiftpoint-x1-control-panel";
        categories = [ "Utility" "Settings" ];
      })
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/swiftpoint
      cp -r fw lib plugins profiles translations $out/lib/swiftpoint/
      # qt.conf points Qt at ./plugins relative to the executable, so the real
      # binary has to stay next to it and $out/bin only gets a wrapper.
      cp qt.conf "Starter Mappings.spcf" $out/lib/swiftpoint/
      install -Dm755 "Swiftpoint X1 Control Panel" \
        "$out/lib/swiftpoint/Swiftpoint X1 Control Panel"
      # The session sets QT_STYLE_OVERRIDE=kvantum for the nixpkgs Qt; the
      # bundled one has no Kvantum plugin and only warns about it.
      makeWrapper "$out/lib/swiftpoint/Swiftpoint X1 Control Panel" \
        $out/bin/swiftpoint-x1-control-panel \
        --unset QT_STYLE_OVERRIDE

      install -Dm644 60-Swiftpoint.rules $out/lib/udev/rules.d/60-Swiftpoint.rules
      install -Dm644 ${icon} $out/share/pixmaps/swiftpoint-x1-control-panel.png
      install -Dm644 "Swiftpoint X1 Control Panel Licence.txt" \
        $out/share/licenses/swiftpoint-x1-control-panel/LICENSE

      runHook postInstall
    '';

    meta = {
      description = "Control panel for Swiftpoint mice (Z/Z2/Z3, Tracer, Creator)";
      homepage = "https://support.swiftpoint.com/portal/en/kb/articles/swiftpoint-x1-control-panel-download";
      license = lib.licenses.unfree;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      platforms = [ "x86_64-linux" ];
      mainProgram = "swiftpoint-x1-control-panel";
    };
  };
in
{
  environment.systemPackages = [ swiftpoint-x1-control-panel ];

  # 60-Swiftpoint.rules opens the hidraw nodes of every Swiftpoint product ID.
  # Its last line additionally tags *all* input event devices with uaccess,
  # which hands the session user read access to every keyboard and mouse on the
  # box -- kept as shipped because the app reads input devices for its gesture
  # setup, but it is broader than this one mouse needs.
  services.udev.packages = [ swiftpoint-x1-control-panel ];

  # Button mappings are applied by the running app, not by the mouse firmware,
  # so it has to stay up for the profiles to take effect.
  systemd.user.services.swiftpoint-x1-control-panel = {
    description = "Swiftpoint X1 Control Panel";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      # "hide" starts it without a window; it only lives in the tray until the
      # desktop entry is launched, which hands the running instance a window
      # instead of starting a second one.
      ExecStart = "${lib.getExe swiftpoint-x1-control-panel} hide";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
