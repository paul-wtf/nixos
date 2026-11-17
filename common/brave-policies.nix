{ ... }:
{
  # Brave Origin reads the same /etc/brave/policies path as the regular build.
  environment.etc."brave/policies/managed/paul.json".text = builtins.toJSON {
    # Origin already ships without these features; the flags stay as a safety net
    # in case we ever switch back to the full Brave build.
    BraveRewardsDisabled = true;
    BraveWalletDisabled  = true;
    BraveVPNDisabled     = true;
    BraveAIChatEnabled   = false;
    BraveNewsDisabled    = true;

    DefaultSearchProviderEnabled    = true;
    DefaultSearchProviderName       = "Brave";
    DefaultSearchProviderSearchURL  = "https://search.brave.com/search?q={searchTerms}";
    DefaultSearchProviderSuggestURL = "https://search.brave.com/complete/search?output=chrome&q={searchTerms}";

    # New tab -> Google
    NewTabPageLocation = "https://search.brave.com";

    # Point Bitwarden at your self-hosted instance
    "3rdparty".extensions."nngceckbapebfimnlniiiahkandclblb".environment.base =
      "https://webvault.paul.wtf";
  };
}
