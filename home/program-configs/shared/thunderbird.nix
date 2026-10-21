{ ... }:
{
  # Accounts are set up by hand in the app; Nix only provides the client
  # and the Catppuccin theme.
  programs.thunderbird = {
    enable = true;
    profiles.default = {
      isDefault = true;
      settings = {
        # Sideloaded extensions (the Catppuccin theme) start disabled otherwise.
        "extensions.autoDisableScopes" = 0;
        # Gecko ID from the manifest of catppuccin's mocha-teal .xpi.
        "extensions.activeThemeID" = "{afbc8f52-40b6-52c1-aaaa-d40bb52dce6e}";
      };
    };
  };

  catppuccin.thunderbird.profile = "default";
}
