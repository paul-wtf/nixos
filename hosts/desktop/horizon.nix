{ pkgs, lib, ... }:
let
  release = lib.importJSON ./horizon.json;

  horizon-launcher-unwrapped = pkgs.stdenvNoCC.mkDerivation {
    pname = "horizon-launcher-unwrapped";
    inherit (release) version;

    src = pkgs.fetchurl {
      url = "https://github.com/ludovic111/horizon/releases/download/launcher@${release.version}/horizon-launcher-linux-x86_64.tar.gz";
      inherit (release) hash;
    };
    sourceRoot = ".";

    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;

    installPhase = ''
      install -Dm755 horizon-launcher $out/bin/horizon-launcher
    '';
  };

  desktopItem = pkgs.makeDesktopItem {
    name = "horizon-launcher";
    desktopName = "Horizon";
    genericName = "Game launcher";
    comment = "Install, prepare and play Horizon, Minecraft: Java Edition rewritten in Rust";
    exec = "horizon-launcher";
    icon = "horizon";
    categories = [ "Game" ];
    startupWMClass = "horizon-launcher";
  };

  # An FHS env rather than patchelf: the launcher downloads the game's own
  # prebuilt binaries at runtime and starts them as its children.
  horizon-launcher = pkgs.buildFHSEnv {
    pname = "horizon-launcher";
    inherit (release) version;

    targetPkgs = pkgs: with pkgs; [
      horizon-launcher-unwrapped
      vulkan-loader
      wayland
      libxkbcommon
      libx11
      libxcb
      libxcursor
      libxi
      libxrandr
      alsa-lib
      udev
      zulu25
      python3
      xdg-utils
    ];

    # The launcher rewrites ~/.local/share/applications/horizon-launcher.desktop
    # to point at its own binary, which cannot start outside this env.
    profile = ''
      export HORIZON_LAUNCHER_NO_SELF_UPDATE=1
      export HORIZON_LAUNCHER_DESKTOP_EXEC=/run/current-system/sw/bin/horizon-launcher
      export JAVA_HOME=${pkgs.zulu25}
    '';

    runScript = "horizon-launcher";

    extraInstallCommands = ''
      install -Dm644 -t $out/share/applications ${desktopItem}/share/applications/*.desktop
    '';

    meta = {
      description = "Launcher for Horizon, Minecraft: Java Edition rewritten in Rust";
      homepage = "https://github.com/ludovic111/horizon";
      license = lib.licenses.mit;
      mainProgram = "horizon-launcher";
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  environment.systemPackages = [ horizon-launcher ];
}
