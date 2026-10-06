{ pkgs, lib, ... }:
let
  tiny4linux = pkgs.rustPlatform.buildRustPackage (finalAttrs: {
    pname = "tiny4linux";
    version = "2.2.1";

    src = pkgs.fetchFromGitHub {
      owner = "OpenFoxes";
      repo = "Tiny4Linux";
      tag = "v${finalAttrs.version}";
      hash = "sha256-eNvFa8h3XDnaSdM1iU6zbncUqBXzPrXgPzPziHJkZLA=";
    };

    cargoHash = "sha256-ZURy8sn2ljW6qrLt5ILM8vnRKCUhYqWdy1s8pExDDnc=";

    buildFeatures = [ "gui" "cli" ];
    doCheck = false;

    postInstall = ''
      assets=$(find target -path '*/release/assets' -type d | head -n1)
      install -Dm644 $assets/icon.png $out/share/icons/hicolor/256x256/apps/tiny4linux.png
      install -Dm644 $assets/icon-widget.png $out/share/icons/hicolor/256x256/apps/tiny4linux-widget.png
      install -Dm644 -t $out/share/applications src/gui/*.desktop
    '';

    # iced loads its windowing and GPU backends with dlopen.
    postFixup = ''
      patchelf --add-rpath ${lib.makeLibraryPath (with pkgs; [ wayland libxkbcommon vulkan-loader libGL ])} \
        $out/bin/tiny4linux-gui
    '';

    meta = {
      description = "GUI and CLI controller for the OBSBOT Tiny 2";
      homepage = "https://github.com/OpenFoxes/Tiny4Linux";
      license = lib.licenses.eupl12;
      mainProgram = "tiny4linux-gui";
    };
  });
in
{
  environment.systemPackages = [ tiny4linux ];
}
