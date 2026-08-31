{ pkgs, tidaluna, gsr-ui-nix, ... }:
let
  # tidal-hifi (TidaLuna) wrapped to pin Electron's safeStorage to
  # gnome-libsecret. Otherwise 'auto' picks a backend inconsistently under
  # Hyprland, luna-trust-store.enc cannot be decrypted and TidaLuna asks for
  # plugin permissions again on EVERY start. Requires an unlocked
  # gnome-keyring (see common/sddm.nix).
  tidal-hifi = pkgs.symlinkJoin {
    name = "tidal-hifi-gnome-libsecret";
    paths = [ tidaluna.packages.${pkgs.stdenv.hostPlatform.system}.default ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/tidal-hifi --add-flags "--password-store=gnome-libsecret"
    '';
  };
in
{
  nixpkgs.config.allowUnfree = true;
  # CLI tools that have a home-manager module enabled in home/program-configs/
  # (tmux, kitty, alacritty, fastfetch, hyfetch, ripgrep, eza, bat) live there
  # as the single source, not here. vim stays system-wide on purpose:
  # environment.variables.EDITOR = "vim" and root sessions need it too.
  environment.systemPackages = with pkgs; [
    vim
    htop
    tidal-hifi
    pavucontrol
    grimblast
    usbutils
    mpv
    cowsay
    fluxcd
    kubectl
    teleport
    (prismlauncher.override {
      jdks = [
        zulu8
        zulu17
        zulu21
        zulu25
      ];
    })
    telegram-desktop
    seadrive-gui
    davinci-resolve-studio
    fping
    gh
    ffmpeg
    teamspeak6-client
    nodejs
    pnpm
    s-tui
    goverlay
    labymod-launcher
    gnumake
    gcc
    python3
    kdePackages.ark
    noriskclient-launcher
    obsidian
    lm_sensors
    nvtopPackages.full
    furmark
  ];
  programs.kdeconnect.enable = true;

  # The NoRisk launcher downloads its own generic Zulu JDK to
  # ~/.local/share/noriskclientv3/meta/java/ and starts the client with it.
  # Without nix-ld the binary lacks the dynamic linker under /lib64
  # ("Could not start dynamically linked executable").
  programs.nix-ld.enable = true;

  programs.fish.enable                = true;
  programs.nano.enable                = false;
  # gpu-screen-recorder + ShadowPlay-style overlay UI. The module itself is
  # the upstream nixos one (it grew ui.* options, which collided with the
  # gsr-ui-nix module -> that module is no longer imported in flake.nix).
  # All three packages still come from the gsr-ui-nix flake because its
  # recorder is newer than the one in nixpkgs; the flake packages take the
  # same override arguments the upstream module passes in.
  # ui.enable sets up the security wrapper for gsr-global-hotkeys
  # (cap_setuid+ep); the overlay itself is started from hyprland.nix.
  programs.gpu-screen-recorder = let
    gsr = gsr-ui-nix.packages.${pkgs.stdenv.hostPlatform.system};
  in {
    package         = gsr.gpu-screen-recorder;
    enable          = true;
    ui.enable       = true;
    ui.package      = gsr.gpu-screen-recorder-ui;
    ui.notifPackage = gsr.gpu-screen-recorder-notification;
  };
  programs.git = {
    enable = true;
    lfs.enable = true;
    config.user = {
      name = "Paul Reitmayer";
      email = "paul.reitmayer@pm.me";
      signingKey = "~/.ssh/id_ed25519.pub";
    };
    config.gpg.format = "ssh";
    config.commit.gpgsign = "true";
  };
}
