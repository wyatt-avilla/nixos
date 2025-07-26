{
  pkgs,
  lib,
  config,
  ...
}:
let
  cloudflaredCredentialsSecretFile = "${config.variables.secretsDirectory}/cloudflared-credentials";

  credentialsFile = "/etc/cloudflared/homelab.json";

  copyCloudflaredCredentials = pkgs.writeShellScriptBin "copy-cloudflared-credentials" ''
    set -euo pipefail

    echo "[cloudflared setup] Copying credentials to ${credentialsFile}"

    install -Dm600 "${cloudflaredCredentialsSecretFile}" "${credentialsFile}"

    chown root:root "${credentialsFile}"
    echo "[cloudflared setup] Credentials installed with root ownership and 600 perms"
  '';
in
{
  options.variables.localip = lib.mkOption {
    type = lib.types.str;
    default = "10.0.5.69";
  };

  options.variables.domain = lib.mkOption {
    type = lib.types.str;
    default = "wyatt.wtf";
  };

  config = {
    services.cloudflared = {
      enable = true;
      tunnels = {
        "homelab" = {
          inherit credentialsFile;
          ingress = {
            "immich.${config.variables.domain}" = {
              service = "http://localhost:2283";
            };
            "filebrowser.${config.variables.domain}" = {
              service = "http://localhost:8789";
            };
            "bin.${config.variables.domain}" = {
              service = "http://localhost:2233";
            };
          };
          default = "http_status:404";
        };
      };
    };

    systemd.services.copy-cloudflared-credentials = {
      description = "Copies decrypted cloudflared credentials file into expected location";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${copyCloudflaredCredentials}/bin/copy-cloudflared-credentials";
        Type = "oneshot";
      };
    };
  };
}
