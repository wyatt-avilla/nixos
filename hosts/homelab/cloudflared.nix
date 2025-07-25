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

  config = {
    services.cloudflared = {
      enable = true;
      tunnels = {
        "homelab" = {
          inherit credentialsFile;
          ingress = {
            "immich.wyatt.wtf" = {
              service = "http://localhost:2283";
            };
            "filebrowser.wyatt.wtf" = {
              service = "http://localhost:8789";
            };
            "bin.wyatt.wtf" = {
              service = "http://localhost:80";
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
