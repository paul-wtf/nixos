{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    gsr-ui-nix = {
      url = "github:rPlakama/gsr-ui-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tidaluna.url = "github:Inrixia/TidaLuna";
    nixcord.url = "github:FlameFlag/nixcord";
    catppuccin.url = "github:catppuccin/nix";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dotfiles = {
      url = "github:paul-wtf/dotfiles";
      flake = false;
    };
    rodecaster-volume-bridge = {
      url = "github:paul-wtf/rodecaster-volume-bridge";
      flake = false;
    };
    streamcontroller-tidal = {
      url = "github:paul-wtf/streamcontroller-tidal";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, disko, dotfiles, rodecaster-volume-bridge, streamcontroller-tidal, tidaluna, nixcord, catppuccin, gsr-ui-nix, ... }:
  let
    # Upstream bug (still present on nixpkgs master as of 2026-07-21): the
    # package calls wrapGAppsHook manually inside a symlinkJoin where $output
    # is never set -> "wrapGAppsHookHasRunForOutput: bad array subscript".
    # Remove the overlay once the build passes upstream again.
    noriskOverlay = final: prev: {
      noriskclient-launcher = prev.noriskclient-launcher.overrideAttrs (old: {
        # WebKitGTK's DMA-BUF renderer crashes on NVIDIA/Wayland with
        # "Error 71 (Protocol error) dispatching to Wayland display".
        buildCommand = builtins.replaceStrings
          [ "glibPostInstallHook" "gappsWrapperArgsHook" ]
          [
            "output=out\noutputBin=out\nglibPostInstallHook"
            "gappsWrapperArgs+=(--set WEBKIT_DISABLE_DMABUF_RENDERER 1)\ngappsWrapperArgsHook"
          ]
          old.buildCommand;
      });
    };
    # Shared home-manager base settings for mkHost and mkDarwin.
    hmDefaults = {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      # When home-manager takes over existing (imperatively created) files,
      # back them up as *.hm-bak instead of failing activation with
      # "would be clobbered".
      home-manager.backupFileExtension = "hm-bak";
    };
    mkHost = host: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit tidaluna catppuccin streamcontroller-tidal gsr-ui-nix; };
      modules = [
        ./hosts/${host}
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        hmDefaults
        {
          home-manager.extraSpecialArgs = { inherit dotfiles rodecaster-volume-bridge nixcord catppuccin; };
          home-manager.users.paul = import ./home/home-linux.nix;
          nixpkgs.overlays = [ tidaluna.overlays.default noriskOverlay ];
        }
      ];
    };
    mkDarwin = host: nix-darwin.lib.darwinSystem {
      specialArgs = { inherit catppuccin tidaluna; };
      modules = [
        ./hosts/${host}
        home-manager.darwinModules.home-manager
        hmDefaults
        {
          home-manager.extraSpecialArgs = { inherit catppuccin; };
          home-manager.users.paulweber = import ./home/home-darwin.nix;
        }
      ];
    };
  in {
    nixosConfigurations = {
      vm      = mkHost "vm";
      desktop = mkHost "desktop";
      laptop  = mkHost "laptop";
    };

    darwinConfigurations = {
      macbook = mkDarwin "macbook";
    };
  };
}
