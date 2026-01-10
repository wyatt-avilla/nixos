{ lib, config, ... }:
let
  credentialsFile = "/etc/cloudflared/homelab.json";
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
            ${config.variables.domain} = {
              service = "http://localhost:${toString config.services.wyattwtf.port}";
            };
            "www.${config.variables.domain}" = {
              service = "http://localhost:${toString config.services.wyattwtf.port}";
            };
            "immich.${config.variables.domain}" = {
              service = "http://localhost:${toString config.services.immich.port}";
            };
            "filebrowser.${config.variables.domain}" = {
              service = "http://localhost:${toString config.services.filebrowser.settings.port}";
            };
            "bin.${config.variables.domain}" = {
              service = "http://localhost:${toString config.services.microbin.settings.MICROBIN_PORT}";
            };
            "syncthing.${config.variables.domain}" = {
              service = "http://${toString config.services.syncthing.guiAddress}";
            };
          };
          default = "http_status:404";
        };
      };
    };

    systemd.services = config.secrets.mkCopyService {
      name = "cloudflared-credentials";
      source = "${config.variables.secretsDirectory}/cloudflared-credentials";
      dest = credentialsFile;
      mode = "600";
    };
  };
}
