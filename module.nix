{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib)
    mkIf
    getExe
    maintainers
    mkEnableOption
    mkOption
    mkPackageOption
    ;
  inherit (lib.types) str path bool;
  cfg = config.services.emby;
in
{
  options = {
    services.emby = {
      enable = mkEnableOption "Emby Media Server";

      package = mkPackageOption pkgs "emby" { };

      user = mkOption {
        type = str;
        default = "emby";
        description = "User account under which Emby runs.";
      };

      group = mkOption {
        type = str;
        default = "emby";
        description = "Group under which Emby runs.";
      };

      dataDir = mkOption {
        type = path;
        default = "/var/lib/emby";
        description = ''
          Base data directory where Emby stores its program data.
          This is passed to Emby with the `-programdata` flag.
        '';
      };

      openFirewall = mkOption {
        type = bool;
        default = false;
        description = ''
          Open the default ports in the firewall for the media server.
          Opens port 8096 (HTTP) and 8920 (HTTPS).
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    systemd = {
      tmpfiles.settings.embyDirs = {
        "${cfg.dataDir}"."d" = {
          mode = "700";
          inherit (cfg) user group;
        };
        # Emby creates subdirectories automatically, but we ensure the base exists
        "${cfg.dataDir}/plugins"."d" = {
          mode = "755";
          inherit (cfg) user group;
        };
        "${cfg.dataDir}/logs"."d" = {
          mode = "755";
          inherit (cfg) user group;
        };
      };

      services.emby = {
        description = "Emby Media Server";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          UMask = "0077";
          WorkingDirectory = cfg.dataDir;
          ExecStart = "${getExe cfg.package} -programdata '${cfg.dataDir}'";
          Restart = "on-failure";
          TimeoutSec = 15;
          SuccessExitStatus = [
            "0"
            "143"
          ];

          # Security options (adapted from Jellyfin module):
          NoNewPrivileges = true;
          SystemCallArchitectures = "native";
          # AF_NETLINK needed because Emby monitors the network connection
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
            "AF_NETLINK"
          ];
          RestrictNamespaces = !config.boot.isContainer;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          ProtectControlGroups = !config.boot.isContainer;
          ProtectHostname = true;
          ProtectKernelLogs = !config.boot.isContainer;
          ProtectKernelModules = !config.boot.isContainer;
          ProtectKernelTunables = !config.boot.isContainer;
          LockPersonality = true;
          PrivateTmp = !config.boot.isContainer;
          # needed for hardware acceleration
          PrivateDevices = false;
          PrivateUsers = true;
          RemoveIPC = true;

          SystemCallFilter = [
            "~@clock"
            "~@aio"
            "~@chown"
            "~@cpu-emulation"
            "~@debug"
            "~@keyring"
            "~@memlock"
            "~@module"
            "~@mount"
            "~@obsolete"
            "~@privileged"
            "~@raw-io"
            "~@reboot"
            "~@setuid"
            "~@swap"
          ];
          SystemCallErrorNumber = "EPERM";
        };
      };
    };

    users.users = mkIf (cfg.user == "emby") {
      emby = {
        inherit (cfg) group;
        isSystemUser = true;
      };
    };

    users.groups = mkIf (cfg.group == "emby") {
      emby = { };
    };

    networking.firewall = mkIf cfg.openFirewall {
      # Emby default ports
      allowedTCPPorts = [
        8096 # HTTP
        8920 # HTTPS
      ];
    };
  };
}
