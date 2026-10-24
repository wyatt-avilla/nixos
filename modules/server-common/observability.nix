{
  config,
  lib,
  ...
}:
let
  cfg = config.services.homelabObservability;
  notifier = config.services.homelabNotifications;
  isHomelab = config.networking.hostName == "barachiel";
  homeIp = config.variables.homelab.wireguard.ip;
in
{
  imports = [
    ./notifications
    ./prometheus.nix
  ];
  options.services.homelabObservability = {
    enable = lib.mkEnableOption "host and application observability";
    peer = lib.mkOption {
      type = lib.types.str;
      default = if isHomelab then config.variables.vps.wireguard.ip else homeIp;
    };
    failureSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 120;
    };
  };
  config = lib.mkIf cfg.enable {
    systemd.services.notification-check = {
      description = "Check peer, monitoring readiness, and failed units";
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "homelab-notifications";
        Group = "homelab-notifications";
        StateDirectory = "homelab-notifications";
        StateDirectoryMode = "0750";
        UMask = "0027";
        ExecStart = "${lib.getExe notifier.package} check";
        TimeoutStartSec = "60s";
        AmbientCapabilities = [ "CAP_NET_RAW" ];
        CapabilityBoundingSet = [ "CAP_NET_RAW" ];
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };
    systemd.timers.notification-check = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "30s";
        AccuracySec = "1s";
      };
    };
    services = {
      homelabNotifications.enable = true;
      homelabNotifications.checkSettings = {
        inherit (cfg) peer failureSeconds;
      };
    };
  };
}
