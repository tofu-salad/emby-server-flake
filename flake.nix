{
  description = "Emby Media Server flake package with NixOS module";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };
  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      emby = pkgs.stdenv.mkDerivation rec {
        pname = "emby-server";
        version = "4.8.11.0";
        src = pkgs.fetchurl {
          url = "https://github.com/MediaBrowser/Emby.Releases/releases/download/${version}/${pname}-deb_${version}_amd64.deb";
          sha256 = "sha256-Zf3Klu6sQysbG9i8W64gknTG3+suLDS0GpaVfyU5TEA=";
        };

        buildInputs = [
          pkgs.dpkg
          pkgs.lttng-ust_2_12
          pkgs.zlib
        ];

        nativeBuildInputs = [
          pkgs.autoPatchelfHook
          pkgs.makeWrapper
        ];

        # Tell autoPatchelfHook where to find the bundled libraries
        autoPatchelfIgnoreMissingDeps = [
          "libavdevice.so.59"
          "libavfilter.so.8"
          "libavformat.so.59"
          "libavcodec.so.59"
          "libpostproc.so.56"
          "libswresample.so.4"
          "libswscale.so.6"
          "libavutil.so.57"
        ];

        unpackPhase = ''
          dpkg-deb -x $src unpacked
          cd unpacked
        '';

        installPhase = ''
          # Copy everything to the output
          cp -r opt/emby-server $out/

          # Remove systemd files and licenses we don't need
          rm -rf $out/lib/systemd
          rm -rf $out/licenses

          # Fix paths in scripts
          find $out/bin -type f -exec sed -i "s|/opt/emby-server|$out|g" {} \;

          # Create bin directory for wrappers
          mkdir -p $out/bin

          # Create wrapper for main emby server (disable auto-updates with empty updatepackage)
          makeWrapper "$out/bin/emby-server" $out/bin/emby \
            --prefix LD_LIBRARY_PATH : "$out/lib:$out/lib/x86_64-linux-gnu" \
            --add-flags "$out/EmbyServer.dll -ffmpeg $out/bin/emby-ffmpeg -ffprobe $out/bin/emby-ffprobe -updatepackage \"\""

          # Create wrapper for emby-ffmpeg that sets up library path
          mv $out/bin/emby-ffmpeg $out/bin/.emby-ffmpeg-unwrapped
          makeWrapper "$out/bin/.emby-ffmpeg-unwrapped" $out/bin/emby-ffmpeg \
            --prefix LD_LIBRARY_PATH : "$out/lib:$out/lib/x86_64-linux-gnu"

          # Create wrapper for emby-ffdetect
          mv $out/bin/emby-ffdetect $out/bin/.emby-ffdetect-unwrapped  
          makeWrapper "$out/bin/.emby-ffdetect-unwrapped" $out/bin/emby-ffdetect \
            --prefix LD_LIBRARY_PATH : "$out/lib:$out/lib/x86_64-linux-gnu"

          # Also wrap the direct ffmpeg/ffprobe binaries
          mv $out/bin/ffmpeg $out/bin/.ffmpeg-unwrapped
          makeWrapper "$out/bin/.ffmpeg-unwrapped" $out/bin/ffmpeg \
            --prefix LD_LIBRARY_PATH : "$out/lib:$out/lib/x86_64-linux-gnu"
            
          mv $out/bin/ffprobe $out/bin/.ffprobe-unwrapped
          makeWrapper "$out/bin/.ffprobe-unwrapped" $out/bin/ffprobe \
            --prefix LD_LIBRARY_PATH : "$out/lib:$out/lib/x86_64-linux-gnu"
        '';

        # Run autoPatchelfHook manually after installPhase
        postFixup = ''
          # Patch all binaries to use system libraries where possible
          # The FFmpeg libraries from the deb will be found via LD_LIBRARY_PATH
          autoPatchelf $out/bin/.emby-ffmpeg-unwrapped || true
          autoPatchelf $out/bin/.emby-ffdetect-unwrapped || true  
          autoPatchelf $out/bin/.ffmpeg-unwrapped || true
          autoPatchelf $out/bin/.ffprobe-unwrapped || true

          # Also patch other binaries
          find $out/bin -name "*.so" -exec autoPatchelf {} \; || true
        '';
      };
    in
    {
      packages.${system}.default = emby;
      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/emby";
      };
      nixosModules.default = import ./module.nix;
    };
}
