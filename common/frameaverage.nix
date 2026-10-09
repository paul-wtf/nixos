{ pkgs, ... }:
let
  # Blends every 4 consecutive frames into one and keeps every 4th, so a 240 fps
  # replay becomes 60 fps with natural motion blur. The output stays HDR10
  # (BT.2020/PQ, 10-bit, full range), tagged on the frames and in the stream.
  frameaverage = import ./ffmpeg-batch.nix { inherit pkgs; } {
    name = "frameaverage";
    suffix = "_60fps.mp4";
    description = "Averages every 4 frames into one (240 -> 60 fps motion blur) and encodes HDR10 AV1 via NVENC.";
    inputArgs = "-hwaccel cuda";
    outputArgs = ''
      -map 0 \
      -vf "tmix=frames=4,framestep=4,setparams=range=pc:color_primaries=bt2020:color_trc=smpte2084:colorspace=bt2020nc" \
      -c:v av1_nvenc -preset p7 -tune hq -rc vbr -cq 20 -b:v 0 \
      -pix_fmt p010le \
      -color_range pc -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc \
      -c:a copy \
    '';
  };
in
{
  environment.systemPackages = [ frameaverage ];
}
