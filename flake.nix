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
        ];

        nativeBuildInputs = [
          pkgs.autoPatchelfHook
          pkgs.makeWrapper
        ];

        unpackPhase = "dpkg-deb -x $src $out";

        installPhase = ''
          mkdir -p $out/bin
          cp -r * "$out/opt/emby-server"
          rm -rf $out/opt/emby-server/lib/systemd
          rm -rf $out/opt/emby-server/licenses

          sed -i "s|/opt|$out/opt|g" $out/opt/emby-server/bin/*

          makeWrapper "$out/opt/emby-server/bin/emby-server" $out/bin/emby \
            --prefix LD_LIBRARY_PATH : "$out/opt/emby-server/lib" \
            --add-flags "$out/opt/emby-server/EmbyServer.dll -ffmpeg $out/opt/emby-server/bin/emby-ffmpeg -ffprobe $out/opt/emby-server/bin/emby-ffprobe"

          makeWrapper "$out/opt/emby-server/bin/emby-ffmpeg" $out/bin/emby-ffmpeg \
            --prefix LD_LIBRARY_PATH : "$out/opt/emby-server/lib"

          makeWrapper "$out/opt/emby-server/bin/emby-ffdetect" $out/bin/emby-ffdetect \
            --prefix LD_LIBRARY_PATH : "$out/opt/emby-server/lib"
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
