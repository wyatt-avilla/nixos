{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.variables) domain;

  deployHost = "deploy.${domain}";
  webhookPort = 9000;
  webhookSecretFile = "${config.variables.secretsDirectory}/deploy-webhook-secret";
  homelabTriggerKeyFile = "/etc/deploy/homelab-trigger-key";
  homelabTriggerKeySecret = "${config.variables.secretsDirectory}/homelab-deploy-trigger-private-key";

  relayScript = pkgs.writeShellApplication {
    name = "relay-nixos-deploy";
    runtimeInputs = with pkgs; [
      coreutils
      openssh
    ];
    text = ''
      set -euo pipefail

      if [ "$#" -lt 2 ]; then
        echo "usage: relay-nixos-deploy start <run-id> <sha> | status <run-id>" >&2
        exit 64
      fi

      command="$1"
      shift

      ssh_common=(
        -i ${lib.escapeShellArg homelabTriggerKeyFile}
        -o IdentitiesOnly=yes
        -o StrictHostKeyChecking=accept-new
        -o UserKnownHostsFile=/var/lib/webhook/known_hosts
        deploy@${config.variables.homelab.wireguard.ip}
      )

      case "$command" in
        start)
          if [ "$#" -ne 2 ]; then
            echo "usage: relay-nixos-deploy start <run-id> <sha>" >&2
            exit 64
          fi

          run_id="$1"
          sha="$2"

          if [[ ! "$run_id" =~ ^[0-9]+$ ]]; then
            echo "invalid run id: $run_id" >&2
            exit 65
          fi

          if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
            echo "invalid sha: $sha" >&2
            exit 65
          fi

          exec ssh "''${ssh_common[@]}" -- deploy-start "$run_id" "$sha"
          ;;
        status)
          if [ "$#" -ne 1 ]; then
            echo "usage: relay-nixos-deploy status <run-id>" >&2
            exit 64
          fi

          run_id="$1"

          if [[ ! "$run_id" =~ ^[0-9]+$ ]]; then
            echo "invalid run id: $run_id" >&2
            exit 65
          fi

          exec ssh "''${ssh_common[@]}" -- deploy-status "$run_id"
          ;;
        *)
          echo "usage: relay-nixos-deploy start <run-id> <sha> | status <run-id>" >&2
          exit 64
          ;;
      esac
    '';
  };
in
{
  services.webhook = {
    enable = true;
    ip = "127.0.0.1";
    port = webhookPort;
    urlPrefix = "hooks";
    openFirewall = false;
    hooksTemplated = {
      nixos-deploy-start = ''
        {
          "id": "nixos-deploy-start",
          "execute-command": "${lib.getExe relayScript}",
          "include-command-output-in-response": true,
          "include-command-output-in-response-on-error": true,
          "response-message": "deploy queued",
          "pass-arguments-to-command": [
            {
              "source": "string",
              "name": "start"
            },
            {
              "source": "payload",
              "name": "run_id"
            },
            {
              "source": "payload",
              "name": "sha"
            }
          ],
          "trigger-rule": {
            "and": [
              {
                "match": {
                  "type": "payload-hmac-sha256",
                  "secret": "{{ credential "deploy-webhook-secret" | js }}",
                  "parameter": {
                    "source": "header",
                    "name": "X-Hub-Signature-256"
                  }
                }
              },
              {
                "match": {
                  "type": "value",
                  "value": "wyatt-avilla/nixos",
                  "parameter": {
                    "source": "payload",
                    "name": "repository"
                  }
                }
              },
              {
                "match": {
                  "type": "value",
                  "value": "refs/heads/main",
                  "parameter": {
                    "source": "payload",
                    "name": "ref"
                  }
                }
              },
              {
                "match": {
                  "type": "value",
                  "value": "all",
                  "parameter": {
                    "source": "payload",
                    "name": "target"
                  }
                }
              },
              {
                "match": {
                  "type": "regex",
                  "regex": "^[0-9]+$",
                  "parameter": {
                    "source": "payload",
                    "name": "run_id"
                  }
                }
              },
              {
                "match": {
                  "type": "regex",
                  "regex": "^[0-9a-f]{40}$",
                  "parameter": {
                    "source": "payload",
                    "name": "sha"
                  }
                }
              }
            ]
          }
        }
      '';

      nixos-deploy-status = ''
        {
          "id": "nixos-deploy-status",
          "execute-command": "${lib.getExe relayScript}",
          "include-command-output-in-response": true,
          "include-command-output-in-response-on-error": true,
          "response-headers": [
            {
              "name": "Content-Type",
              "value": "application/json"
            }
          ],
          "pass-arguments-to-command": [
            {
              "source": "string",
              "name": "status"
            },
            {
              "source": "payload",
              "name": "run_id"
            }
          ],
          "trigger-rule": {
            "and": [
              {
                "match": {
                  "type": "payload-hmac-sha256",
                  "secret": "{{ credential "deploy-webhook-secret" | js }}",
                  "parameter": {
                    "source": "header",
                    "name": "X-Hub-Signature-256"
                  }
                }
              },
              {
                "match": {
                  "type": "value",
                  "value": "wyatt-avilla/nixos",
                  "parameter": {
                    "source": "payload",
                    "name": "repository"
                  }
                }
              },
              {
                "match": {
                  "type": "value",
                  "value": "refs/heads/main",
                  "parameter": {
                    "source": "payload",
                    "name": "ref"
                  }
                }
              },
              {
                "match": {
                  "type": "regex",
                  "regex": "^[0-9]+$",
                  "parameter": {
                    "source": "payload",
                    "name": "run_id"
                  }
                }
              }
            ]
          }
        }
      '';
    };
  };

  systemd.services =
    (config.secrets.mkCopyService {
      name = "deploy-copy-homelab-trigger-key";
      source = homelabTriggerKeySecret;
      dest = homelabTriggerKeyFile;
      inherit (config.services.webhook) user group;
      mode = "400";
      consumerService = config.systemd.services.webhook;
      stripFinalNewline = false;
    })
    // {
      webhook = {
        serviceConfig = {
          LoadCredential = [ "deploy-webhook-secret:${webhookSecretFile}" ];
          StateDirectory = "webhook";
        };
      };
    };

  services.nginx.virtualHosts.${deployHost} = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString webhookPort}";
      extraConfig = ''
        proxy_request_buffering off;
      '';
    };
  };
}
