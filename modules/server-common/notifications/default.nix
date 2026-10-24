{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.services.homelabNotifications;
  settings = pkgs.writeText "notifications.json" (
    builtins.toJSON (
      {
        inherit (cfg)
          sender
          recipient
          port
          reminderSeconds
          resendUrl
          ;
        host = config.networking.hostName;
        database = "/var/lib/homelab-notifications/queue.sqlite";
      }
      // cfg.checkSettings
    )
  );
  command = pkgs.writeShellApplication {
    name = "homelab-notify";
    runtimeInputs = [
      pkgs.python3
      pkgs.systemd
      pkgs.iputils
    ];
    text = ''
      exec python3 ${./notifier.py} --config ${settings} "$@"
    '';
  };
  serviceConfig = {
    User = "homelab-notifications";
    Group = "homelab-notifications";
    StateDirectory = "homelab-notifications";
    StateDirectoryMode = "0750";
    UMask = "0027";
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    NoNewPrivileges = true;
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
  };
  unitTypes = [
    "service"
    "socket"
    "timer"
    "path"
    "mount"
    "automount"
    "swap"
    "target"
    "scope"
  ];
in
{
  options.services.homelabNotifications = {
    enable = lib.mkEnableOption "durable Resend notifications";
    sender = lib.mkOption {
      type = lib.types.str;
      default = "alerts@${inputs.nix-secrets.nixosModules.plainSecrets.domain.personal}";
    };
    recipient = lib.mkOption {
      type = lib.types.str;
      default = inputs.nix-secrets.nixosModules.plainSecrets.email.personal;
    };
    credentialPath = lib.mkOption {
      type = lib.types.str;
      default = config.sops.secrets.resend-api-key.path;
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 9169;
    };
    reminderSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 21600;
    };
    resendUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://api.resend.com/emails";
      description = "Resend endpoint; override only for a local test server.";
    };
    checkSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      internal = true;
      description = "Independent checker configuration supplied by observability.";
    };
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = command;
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.homelab-notifications = { };
    users.users.homelab-notifications = {
      isSystemUser = true;
      group = "homelab-notifications";
    };
    environment.systemPackages = [ command ];
    sops.secrets.resend-api-key.restartUnits = [ "homelab-notifications.service" ];
    systemd = {
      packages = [
        (pkgs.runCommand "notification-failure-dropins" { } ''
          for type in ${lib.concatStringsSep " " unitTypes}; do
            mkdir -p "$out/lib/systemd/system/$type.d"
            printf '[Unit]\nOnFailure=notification-failure@%%n.service\n' > "$out/lib/systemd/system/$type.d/50-notifications.conf"
          done
          mkdir -p "$out/lib/systemd/system/notification-failure@.service.d"
          ln -s /dev/null "$out/lib/systemd/system/notification-failure@.service.d/50-notifications.conf"
        '')
      ];
      services.homelab-notifications = {
        description = "Durable Resend notification delivery and Alertmanager receiver";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "sops-nix.service"
        ];
        wants = [ "network-online.target" ];
        serviceConfig = serviceConfig // {
          ExecStart = "${lib.getExe command} serve";
          LoadCredential = [ "resend-api-key:${cfg.credentialPath}" ];
          Restart = "always";
          RestartSec = "5s";
        };
      };
      services."notification-failure@" = {
        description = "Queue notification for failed unit %i";
        serviceConfig = serviceConfig // {
          Type = "oneshot";
          ExecStart = "${lib.getExe command} unit-failure %i";
        };
      };
    };
  };
}
