{ pkgs, ... }:
let
  # AMD X3D CCD switcher (cache vs. frequency CCD). gamemode calls this via
  # sudo on game start/end; root is required for the sysfs write access.
  x3d-mode = pkgs.writeShellScriptBin "x3d-mode" ''
    set -eu
    mode="''${1:-}"
    case "$mode" in
      cache|frequency) ;;
      *) echo "Usage: x3d-mode <cache|frequency>" >&2; exit 1 ;;
    esac
    found=0
    for f in /sys/bus/platform/drivers/amd_x3d_vcache/*/amd_x3d_mode; do
      [ -e "$f" ] || continue
      printf '%s' "$mode" > "$f"
      found=1
    done
    [ "$found" -eq 1 ] || { echo "x3d-mode: no amd_x3d_vcache device found" >&2; exit 1; }
  '';

  proton-cachyos = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "proton-cachyos";
    version = "11.0-20260703-slr";

    src = pkgs.fetchzip {
      url = "https://github.com/CachyOS/proton-cachyos/releases/download/cachyos-${finalAttrs.version}/proton-cachyos-${finalAttrs.version}-x86_64.tar.xz";
      hash = "sha256-jOcPeEkBBPPNqyjXBoHm1Nk8AexPiLhx5+385NjUPT0=";
    };

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    outputs = [ "out" "steamcompattool" ];

    installPhase = ''
      runHook preInstall
      echo "Use programs.steam.extraCompatPackages instead." > $out
      mkdir $steamcompattool
      ln -s $src/* $steamcompattool
      rm $steamcompattool/compatibilitytool.vdf
      cp $src/compatibilitytool.vdf $steamcompattool
      runHook postInstall
    '';

    # Steam keys per-game tool choices by the internal name, so a version-free
    # name keeps them across updates.
    preFixup = ''
      substituteInPlace "$steamcompattool/compatibilitytool.vdf" \
        --replace-fail "proton-cachyos-${finalAttrs.version}-x86_64" "proton-cachyos"
    '';
  });
in
{
  # ── Steam + Proton env (from Arch steam-env.conf — Steam only, not global) ──
  programs.steam = {
    enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin proton-cachyos ];
    package = pkgs.steam.override {
      # gamescope/gamemoderun/mangohud also available inside the Steam FHS
      extraPkgs = ps: with ps; [ mangohud gamescope gamemode ];
      extraEnv = {
        MANGOHUD = "1";                          # HUD in all Vulkan games
        PULSE_LATENCY_MSEC = "60";               # avoid Wine audio crackling
        PROTON_ENABLE_WAYLAND = "1";             # native Wayland (Hyprland)
        PROTON_ENABLE_HDR = "1";
        DXVK_HDR = "1";
        PROTON_DLSS_UPGRADE = "1";               # auto-upgrade DLSS DLLs
        PROTON_DLSS_INDICATOR = "1";
        PROTON_ENABLE_NVAPI = "1";
        PROTON_ENABLE_NGX_UPDATER = "1";
        # PROTON_NVIDIA_LIBS (PhysX/CUDA in the prefix) is disabled: it makes
        # proton look for NVAPI under files/lib/wine/nvidia-libs/nvapi, which
        # GE-Proton does not ship (its dxvk-nvapi DLLs live in files/lib/wine/nvapi).
        # Result was a FileNotFoundError during prefix setup on every game start.
        PROTON_LOCAL_SHADER_CACHE = "1";
        PROTON_USE_NTSYNC = "1";                 # ntsync instead of fsync (/dev/ntsync)
        PROTON_VKD3D_HEAP = "1";                 # fixes NVIDIA Xid 109 crashes
        __GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";
      };
    };
  };

  # ── GTA V Enhanced Online under Proton ──
  # Per github.com/WerIstLuka/GTAOnlineLinux: blackholing these BattlEye hosts
  # is what lets the game into Online. The other two steps of that guide cannot
  # live here -- x64/data/startup.meta sits in the Steam library, and the
  # PROTON_BATTLEYE_RUNTIME path is a per-game launch option.
  networking.hosts."0.0.0.0" = [
    "test-s1.battleye.com"
    "paradiseenhanced-s1.battleye.com"
  ];

  # ── gamescope (HDR/adaptive-sync wrapper) ──
  programs.gamescope = {
    enable = true;
    capSysNice = true;   # real-time priority
  };

  # ── gamemode + X3D CCD switch ──
  programs.gamemode = {
    enable = true;
    settings = {
      general.renice = 0;
      cpu = {
        # 9950X3D: do not park cores, pin the game to cores.
        park_cores = "no";
        pin_cores = "yes";
      };
      custom = {
        # Prefer the cache CCD while gaming, afterwards back to the frequency CCD.
        start = "/run/wrappers/bin/sudo ${x3d-mode}/bin/x3d-mode cache";
        end = "/run/wrappers/bin/sudo ${x3d-mode}/bin/x3d-mode frequency";
      };
    };
  };

  # gamemoded runs as the user -> NOPASSWD sudo ONLY for the x3d-mode write access.
  security.sudo.extraRules = [{
    users = [ "paul" ];
    commands = [{
      command = "${x3d-mode}/bin/x3d-mode";
      options = [ "NOPASSWD" ];
    }];
  }];

  # ── zram (orders of magnitude faster than disk swap) + swap tuning ──
  zramSwap.enable = true;   # defaults: zstd, 50% of RAM
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };

  # ── Tools ──
  environment.systemPackages = with pkgs; [
    mangohud
    x3d-mode
    vulkan-tools
    wineWow64Packages.stable
    winetricks
    zenity
  ];
}
