{ pkgs, ... }:
let
  # DaVinci Resolve does not decode AAC audio on Linux, and AV1 video is a
  # delivery codec (long-GOP, hard to decode, Resolve support shaky).
  # That is why we transcode after the standard Resolve ingest: video -> DNxHR
  # HQ (8-bit 4:2:2), audio -> PCM (pcm_s16le), into a .mov container. That is
  # guaranteed to import and scrubs smoothly.
  #
  # The AV1 decode runs via NVDEC on the GPU (-hwaccel cuda), the frames are
  # then pulled into RAM for the CPU DNxHR encoder (NVENC cannot do DNxHR).
  # For codecs without NVDEC support ffmpeg automatically falls back to
  # software decoding.
  resolve-reencode = import ./ffmpeg-batch.nix { inherit pkgs; } {
    name = "resolve-reencode";
    suffix = "_resolve.mov";
    description = "Transcodes video to DNxHR HQ and audio to PCM (s16le) into a .mov container so that DaVinci Resolve can import the file.";
    inputArgs = "-hwaccel cuda";
    outputArgs = ''
      -map 0:v:0 -map 0:a? \
      -c:v dnxhd -profile:v dnxhr_hq -pix_fmt yuv422p \
      -c:a pcm_s16le \
    '';
  };
in
{
  environment.systemPackages = [ resolve-reencode ];
}
