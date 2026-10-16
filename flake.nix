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
    humanizer = {
      url = "github:blader/humanizer";
      flake = false;
    };
    # No nixpkgs follows: the binary cache only serves builds against the
    # flake's own pinned nixpkgs.
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, disko, dotfiles, rodecaster-volume-bridge, streamcontroller-tidal, tidaluna, nixcord, catppuccin, gsr-ui-nix, humanizer, llm-agents, ... }:
  let
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
      specialArgs = { inherit tidaluna catppuccin streamcontroller-tidal gsr-ui-nix llm-agents; };
      modules = [
        ./hosts/${host}
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        hmDefaults
        {
          home-manager.extraSpecialArgs = { inherit dotfiles rodecaster-volume-bridge nixcord catppuccin humanizer; };
          home-manager.users.paul = import ./home/home-linux.nix;
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
          home-manager.extraSpecialArgs = { inherit catppuccin humanizer; };
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
