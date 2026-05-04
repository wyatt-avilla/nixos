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
  copyTriggerKeyService = "copy-secret-deploy-copy-homelab-trigger-key.service";

  relayScript = pkgs.writeShellApplication {
    name = "relay-nixos-deploy";
    runtimeInputs = with pkgs; [
      openssh
    ];
    text = ''
      set -euo pipefail

      if [ "$#" -ne 1 ]; then
        echo "usage: relay-nixos-deploy <sha>" >&2
        exit 64
      fi

      sha="$1"

      case "$sha" in
        [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
        *)
          echo "invalid sha: $sha" >&2
          exit 65
          ;;
      esac

      exec ssh \
        -i ${lib.escapeShellArg homelabTriggerKeyFile} \
        -o IdentitiesOnly=yes \
        -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile=/var/lib/webhook/known_hosts \
        deploy@${config.variables.homelab.wireguard.ip} \
        -- deploy-all "$sha"
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
    hooksTemplated.nixos-deploy = ''
      {
        "id": "nixos-deploy",
        "execute-command": "${lib.getExe relayScript}",
        "response-message": "deploy queued",
        "pass-arguments-to-command": [
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
  };

  systemd.services =
    (config.secrets.mkCopyService {
      name = "deploy-copy-homelab-trigger-key";
      source = homelabTriggerKeySecret;
      dest = homelabTriggerKeyFile;
      inherit (config.services.webhook) user group;
      mode = "400";
      before = [ "webhook.service" ];
      stripFinalNewline = false;
    })
    // {
      webhook = {
        requires = [ copyTriggerKeyService ];
        after = [ copyTriggerKeyService ];
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
