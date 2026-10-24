{ pkgs }:
pkgs.testers.runNixOSTest {
  name = "homelab-observability";
  nodes = builtins.listToAttrs (
    map
      (name: {
        inherit name;
        value =
          { lib, ... }:
          {
            imports = [
              ../../modules/server-common/observability.nix
              ../../modules/server-common/service-variables.nix
              ../../modules/server-common/wireguard.nix
            ];
            options = {
              variables.domain = lib.mkOption {
                type = lib.types.str;
                default = "example.org";
              };
              sops.secrets = lib.mkOption {
                type = lib.types.attrs;
                default = { };
              };
            };
            config = {
              _module.args.inputs = { };
              networking = {
                hostName = name;
                firewall.enable = false;
                interfaces.eth1.ipv4.addresses = [
                  {
                    address = if name == "first" then "10.0.0.1" else "10.0.0.2";
                    prefixLength = 24;
                  }
                ];
              };
              environment.etc."mock-resend-key" = {
                text = "mock-test-key";
                mode = "0400";
              };
              systemd = {
                services.mock-resend = {
                  wantedBy = [ "multi-user.target" ];
                  serviceConfig = {
                    ExecStart = "${pkgs.python3}/bin/python3 ${./mock_resend.py}";
                    StateDirectory = "mock-resend";
                  };
                };
                services.intentional-failure.serviceConfig = {
                  Type = "oneshot";
                  ExecStart = "${pkgs.coreutils}/bin/false";
                };
                mounts = [
                  {
                    what = "none";
                    where = "/badmount";
                    type = "observability-test-invalid-filesystem";
                  }
                ];
                timers.notification-check.timerConfig = {
                  OnBootSec = lib.mkForce "2s";
                  OnUnitActiveSec = lib.mkForce "2s";
                };
              };
              services = {
                homelabObservability = {
                  enable = true;
                  peer = if name == "first" then "10.0.0.2" else "10.0.0.1";
                  failureSeconds = 2;
                };
                homelabNotifications = {
                  sender = "alerts@example.org";
                  recipient = "test@example.org";
                  credentialPath = "/etc/mock-resend-key";
                  resendUrl = "http://127.0.0.1:9088/emails";
                };
                prometheus = {
                  globalConfig.scrape_interval = lib.mkForce "2s";
                  globalConfig.evaluation_interval = lib.mkForce "2s";
                  scrapeConfigs = lib.mkForce [
                    {
                      job_name = "mock-apps";
                      metrics_path = "/probe";
                      params.module = [ "http_200" ];
                      static_configs = [
                        {
                          targets = [ "http://127.0.0.1:9088/" ];
                          labels.service = "mock";
                        }
                      ];
                      relabel_configs = [
                        {
                          source_labels = [ "__address__" ];
                          target_label = "__param_target";
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
                  alertmanager.configuration = lib.mkForce {
                    route = {
                      receiver = "test";
                      group_by = [ "alertname" ];
                      group_wait = "1s";
                      group_interval = "1s";
                      repeat_interval = "6h";
                    };
                    receivers = [
                      {
                        name = "test";
                        webhook_configs = [
                          {
                            url = "http://127.0.0.1:9169/alertmanager";
                            send_resolved = true;
                          }
                        ];
                      }
                    ];
                  };
                };
              };
              environment.systemPackages = [
                pkgs.curl
                pkgs.sqlite
                pkgs.iproute2
              ];
              virtualisation.memorySize = 1024;
            };
          };
      })
      [
        "first"
        "second"
      ]
  );
  testScript = ''
    import json

    start_all()
    for machine in (first, second):
        machine.wait_for_unit("homelab-notifications.service")
        machine.wait_for_unit("prometheus.service")
        machine.wait_for_unit("alertmanager.service")
        machine.wait_for_unit("mock-resend.service")
        machine.wait_until_succeeds("curl -fsS http://127.0.0.1:9169/metrics")

    with subtest("monitoring listeners remain private"):
        for port in (9090, 9093, 9100, 9115, 9169):
            second.fail(f"curl -fsS --connect-timeout 2 http://10.0.0.1:{port}/")

    def received(machine, text):
        machine.wait_until_succeeds("grep -F '" + text + "' /var/lib/mock-resend/messages", timeout=180)

    with subtest("systemd failure and recovery without Prometheus"):
        first.succeed("systemctl stop prometheus")
        first.fail("systemctl start intentional-failure")
        received(first, "Unit failed: intentional-failure.service")
        first.succeed("systemctl reset-failed intentional-failure")
        received(first, "Unit failed state cleared: intentional-failure.service")
        first.fail("systemctl start badmount.mount")
        received(first, "Unit failed: badmount.mount")
        first.succeed("systemctl reset-failed badmount.mount")
        received(first, "prometheus is not ready")
        first.succeed("systemctl start prometheus")

    with subtest("peer interruption and recovery"):
        first.succeed("ip link set eth1 down")
        received(second, "WireGuard peer unreachable")
        received(first, "WireGuard peer unreachable")
        first.succeed("ip link set eth1 up")
        for machine in (first, second):
            machine.wait_until_succeeds("grep 'RESOLVED.*WireGuard peer' /var/lib/mock-resend/messages")

    with subtest("queue survives stopped delivery and restart"):
        first.succeed("systemctl stop homelab-notifications")
        first.succeed("runuser -u homelab-notifications -- homelab-notify submit --key offline --summary offline-message")
        first.succeed("systemctl start homelab-notifications")
        received(first, "offline-message")

    with subtest("login probe does not mask backend failure"):
        first.succeed("curl -fsSG http://127.0.0.1:9115/probe --data-urlencode target=http://127.0.0.1:9088/login --data-urlencode module=login_files | grep 'probe_success 1'")
        first.succeed("curl -fsSG http://127.0.0.1:9115/probe --data-urlencode target=http://127.0.0.1:9089/ --data-urlencode module=http_200 | grep 'probe_success 0'")

    with subtest("Prometheus to Alertmanager to Resend, with queued recovery"):
        first.succeed("systemctl stop mock-resend")
        first.wait_until_succeeds("curl -fsS http://127.0.0.1:9090/api/v1/alerts | grep '\"alertname\":\"ApplicationUnavailable\"' | grep '\"state\":\"firing\"'", timeout=240)
        first.wait_until_succeeds("curl -fsS http://127.0.0.1:9169/metrics | grep -E 'notifications_pending [1-9]'", timeout=240)
        first.succeed("systemctl start mock-resend")
        received(first, "Application mock")
        received(first, "RESOLVED: Application mock")

    with subtest("no recursive notification handler"):
        first.succeed("mkdir -p /run/systemd/system/notification-failure@nonexistent.service.service.d")
        first.succeed("printf '[Service]\\nExecStartPre=${pkgs.coreutils}/bin/false\\n' > /run/systemd/system/notification-failure@nonexistent.service.service.d/force-failure.conf")
        first.succeed("systemctl daemon-reload")
        first.fail("systemctl start notification-failure@nonexistent.service.service")
        first.succeed("systemctl is-failed notification-failure@nonexistent.service.service")
        assert first.succeed("systemctl show notification-failure@nonexistent.service.service --property=OnFailure --value").strip() == ""
        units = json.loads(first.succeed("systemctl list-units --all --output=json"))
        assert not any("notification-failure@notification-failure" in unit["unit"] for unit in units)
  '';
}
