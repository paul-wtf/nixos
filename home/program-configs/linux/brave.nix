{ pkgs, ... }:
{
  programs.brave-origin = {
    enable = true;
    extensions = [
      { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
      { id = "clngdbkpkpeebahjckkjfobafhncgmne"; } # Stylus
      { id = "ammjkodgmmoknidbanneddgankgfejfh"; } # 7TV
      { id = "gebbhagfogifgggkldgodflihgfeippi"; } # Return Youtube Dislike
      { id = "mnjggcdmjocbbbhaepdhchncahnbgone"; } # SponsorBlock for Youtube
      { id = "bkkmolkhemgaeaeggcmfbghljjjoofoh"; } # Catppuccin Mocha Theme
      { id = "mmioliijnhnoblpgimnlajmefafdfilb"; } # Shazam
      { id = "jplgfhpmjnbigmhklmmbgecoobifkmpa"; } # Proton VPN
    ];
  };
}
