# Emby Media Server Nix Flake

This Nix flake provides:

- A wrapped Emby Media Server package using the official `.deb` release
- A reusable NixOS module to enable Emby as a system service (`services.emby.enable = true`)

> ⚠️ **Note:** Emby is proprietary software. This flake does **not** build from source, but unpacks and wraps the official `.deb` release.

---

## Usage

### Add the flake as an input in your `flake.nix`

```nix
{
  inputs.emby-flake.url = "github:tofu-salad/emby-server-flake";

  outputs = { self, nixpkgs, emby-flake, ... }: {
    nixosConfigurations.mysystem = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        emby-flake.nixosModules.default
      ];
    };
  };
}
```
### Enable Emby in your NixOS configuration (configuration.nix)
```nix
{
  services.emby.enable = true;
  # Optional overrides:
  # services.emby.user = "emby";
  # services.emby.group = "emby";
  # services.emby.dataDir = "/var/lib/emby/ProgramData-Server";
}
```
### Build the wrapped Emby package
```nix
nix build github:tofu-salad/emby-server-flake
./result/bin/emby
```
### Or run directly (requires sudo)
```nix
nix run github:tofu-salad/emby-server-flake
```
# Credits
Big thanks to [@numkem](https://emby.media/community/index.php?/topic/109786-live-tv-broken-on-47x/#comment-116375) from the emby.media community forum.

NixOS maintainers for Jellyfine service module available [here].(https://github.com/NixOS/nixpkgs/blob/nixos-25.05/nixos/modules/services/misc/jellyfin.nix).

