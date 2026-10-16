{ pkgs }:
# Resamples to 240 fps, blends every 4 consecutive frames into one and keeps
# every 4th, so a replay becomes a steady 60 fps with natural motion blur. The
# resampling stops VFR clips and dips below 240 from lowering the output rate.
# The output stays HDR10 (BT.2020/PQ, 10-bit, full range), tagged on the frames
# and in the stream.
import ./ffmpeg-batch.nix { inherit pkgs; } {
  name = "frameaverage";
  suffix = "_60fps.mp4";
  description = "Averages every 4 frames into one (240 -> 60 fps motion blur) and encodes HDR10 AV1 via NVENC.";
  inputArgs = "-hwaccel cuda";
  # NVENC's automatic level can pick 5.1 Main, which caps 4K at 40 Mbit/s.
  outputArgs = ''
    -map 0 \
    -vf "fps=240,tmix=frames=4,framestep=4,setparams=range=pc:color_primaries=bt2020:color_trc=smpte2084:colorspace=bt2020nc" \
    -c:v av1_nvenc -preset p7 -tune hq -rc vbr -cq 24 -b:v 0 -level 6.3 -tier 1 \
    -pix_fmt p010le \
    -color_range pc -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc \
    -c:a copy \
  '';
}
