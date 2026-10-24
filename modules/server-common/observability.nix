{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.homelabObservability;
  notifier = config.services.homelabNotifications;
  isHomelab = config.networking.hostName == "barachiel";
  homeIp = config.variables.homelab.wireguard.ip;
  inherit (config.variables) domain;

  target = name: url: module: {
    targets = [ url ];
    labels = {
      service = name;
      inherit module;
    };
  };
  publicTargets = [
    (target "website" "https://${domain}/" "http_200")
    (target "website-www" "https://www.${domain}/" "http_200")
    (target "auth" "https://auth.${domain}/ping" "http_200")
    (target "filebrowser" "https://files.${domain}/" "login_files")
    (target "microbin" "https://bin.${domain}/" "login_bin")
    (target "immich" "https://photos.${domain}/api/server/ping" "immich")
    (target "audiobookshelf" "https://audiobooks.${domain}/ping" "audiobookshelf")
    (target "syncthing" "https://syncthing.${domain}/" "login_syncthing")
  ];
  backendTargets = lib.optionals isHomelab [
    (target "website" "http://127.0.0.1:${toString config.services.wyattwtf.port}/" "http_200")
    (target "filebrowser" "http://${homeIp}:${toString config.variables.filebrowser.port}/" "http_200")
    (target "microbin" "http://${homeIp}:${toString config.variables.microbin.port}/" "http_200")
    (target "immich" "http://${homeIp}:${toString config.variables.immich.port}/api/server/ping"
      "immich"
    )
    (target "audiobookshelf" "http://${homeIp}:${toString config.variables.audiobookshelf.port}/ping"
      "audiobookshelf"
    )
    (target "syncthing" "http://${config.services.syncthing.guiAddress}/" "http_200")
  ];
  httpModule = extra: {
    prober = "http";
    timeout = "10s";
    http = {
      valid_status_codes = [ 200 ];
      follow_redirects = false;
      preferred_ip_protocol = "ip4";
    }
    // extra;
  };
  loginModule =
    regexp:
    httpModule {
      valid_status_codes = [ 302 ];
      fail_if_header_not_matches = [
        {
          header = "Location";
          inherit regexp;
        }
      ];
    };
  blackboxConfig = pkgs.writeText "blackbox.json" (
    builtins.toJSON {
      modules = {
        http_200 = httpModule { };
        immich = httpModule { fail_if_body_not_matches_regexp = [ ''"res"\s*:\s*"pong"'' ]; };
        audiobookshelf = httpModule { fail_if_body_not_matches_regexp = [ ''"success"\s*:\s*true'' ]; };
        login_files = loginModule "^https://files\\.${lib.escapeRegex domain}/oauth2/start\\?";
        login_bin = loginModule "^https://bin\\.${lib.escapeRegex domain}/oauth2/start\\?";
        login_syncthing = loginModule "^https://wyatt-avilla\\.cloudflareaccess\\.com/cdn-cgi/access/login/syncthing\\.${lib.escapeRegex domain}\\?";
      };
    }
  );
  rule = alert: expr: duration: summary: {
    inherit alert expr;
    for = duration;
    labels.severity = "warning";
    annotations = {
      inherit summary;
      description = "Host {{ $labels.host }}: {{ $labels.instance }} {{ $labels.mountpoint }} {{ $labels.service }}";
    };
  };
  fs = ''fstype!~"tmpfs|devtmpfs|overlay|squashfs|iso9660|fuse.*",mountpoint!~"/nix/store|/run.*|/proc.*|/sys.*|/dev.*"'';
  writableMounts = lib.concatStringsSep "|" (
    map lib.escapeRegex (
      builtins.attrNames (
        lib.filterAttrs (_: mount: !(builtins.elem "ro" mount.options)) config.fileSystems
      )
    )
  );
in
{
  imports = [ ./notifications ];
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
    rules = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      description = "Prometheus alert rules; override to tune thresholds.";
      default = [
        (rule "HostCPUHigh"
          ''100 * (1 - avg by (instance,host) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) > 90''
          "15m"
          "CPU utilization above 90%"
        )
        (rule "HostMemoryLow" "node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.1" "10m"
          "Available memory below 10%"
        )
        (rule "HostDiskSpaceLow"
          "(node_filesystem_avail_bytes{${fs}} / node_filesystem_size_bytes{${fs}} < 0.1) and on(instance,device,mountpoint) (node_filesystem_readonly == 0)"
          "10m"
          "Filesystem space below 10%"
        )
        (rule "HostInodesLow"
          "(node_filesystem_files_free{${fs}} / node_filesystem_files{${fs}} < 0.1) and on(instance,device,mountpoint) (node_filesystem_files > 0) and on(instance,device,mountpoint) (node_filesystem_readonly == 0)"
          "10m"
          "Filesystem inodes below 10%"
        )
        (rule "HostFilesystemReadOnly"
          "node_filesystem_readonly{${fs},mountpoint=~${builtins.toJSON writableMounts}} == 1"
          "1m"
          "Writable filesystem became read-only"
        )
        (rule "MonitoringScrapeFailed" "up == 0" "2m" "Monitoring scrape failed")
        (rule "PrometheusRuleEvaluationFailed" "increase(prometheus_rule_evaluation_failures_total[5m]) > 0"
          "0m"
          "Prometheus rule evaluation failed"
        )
        (rule "ApplicationUnavailable" "probe_success == 0" "2m"
          "Application {{ $labels.service }} {{ $labels.probe_location }} check failed"
        )
        (rule "NotificationDeliveryStalled" "notifications_oldest_pending_seconds > 900" "2m"
          "Notification queue is stalled"
        )
        (rule "NotificationDeliveryRejected" "notifications_failed > 0" "0m"
          "Notification delivery requires manual retry"
        )
      ];
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
        readiness = {
          prometheus = "http://127.0.0.1:9090/-/ready";
          alertmanager = "http://127.0.0.1:9093/-/ready";
        };
      };
      prometheus = {
        enable = true;
        listenAddress = "127.0.0.1";
        retentionTime = "7d";
        extraFlags = [ "--storage.tsdb.retention.size=1GB" ];
        globalConfig = {
          scrape_interval = "30s";
          evaluation_interval = "30s";
          external_labels.host = config.networking.hostName;
        };
        alertmanagers = [ { static_configs = [ { targets = [ "127.0.0.1:9093" ]; } ]; } ];
        ruleFiles = [
          (pkgs.writeText "host-alerts.json" (
            builtins.toJSON {
              groups = [
                {
                  name = "host-health";
                  inherit (cfg) rules;
                }
              ];
            }
          ))
        ];
        scrapeConfigs = [
          {
            job_name = "local";
            static_configs = [
              {
                targets = [
                  "127.0.0.1:9090"
                  "127.0.0.1:9093"
                  "127.0.0.1:9100"
                  "127.0.0.1:9115"
                  "127.0.0.1:${toString notifier.port}"
                ];
                labels.host = config.networking.hostName;
              }
            ];
          }
          {
            job_name = "applications";
            metrics_path = "/probe";
            scrape_timeout = "15s";
            static_configs = map (
              entry:
              entry
              // {
                labels = entry.labels // {
                  host = config.networking.hostName;
                  probe_location = if isHomelab then "backend" else "public";
                };
              }
            ) (if isHomelab then backendTargets else publicTargets);
            relabel_configs = [
              {
                source_labels = [ "__address__" ];
                target_label = "__param_target";
              }
              {
                source_labels = [ "module" ];
                target_label = "__param_module";
              }
              {
                source_labels = [ "__param_target" ];
                target_label = "instance";
              }
              {
                target_label = "__address__";
                replacement = "127.0.0.1:9115";
              }
            ];
          }
        ];
        exporters.node = {
          enable = true;
          listenAddress = "127.0.0.1";
        };
        exporters.blackbox = {
          enable = true;
          listenAddress = "127.0.0.1";
          configFile = blackboxConfig;
        };
        alertmanager = {
          enable = true;
          listenAddress = "127.0.0.1";
          extraFlags = [ "--cluster.listen-address=" ];
          configuration = {
            route = {
              receiver = "local-notifications";
              group_by = [
                "host"
                "alertname"
              ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "6h";
            };
            receivers = [
              {
                name = "local-notifications";
                webhook_configs = [
                  {
                    url = "http://127.0.0.1:${toString notifier.port}/alertmanager";
                    send_resolved = true;
                  }
                ];
              }
            ];
          };
        };
      };
    };
  };
}
