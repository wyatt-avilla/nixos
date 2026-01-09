{ lib, config, ... }:
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
    sops.secrets.cloudflared-credentials = {
      path = "/etc/cloudflared/homelab.json";
      mode = "0600";
    };

    services.cloudflared = {
      enable = true;
      tunnels = {
        "homelab" = {
          credentialsFile = config.sops.secrets.cloudflared-credentials.path;
          ingress = {
            ${config.variables.domain} = {
              service = "http://localhost:${builtins.toString config.services.wyattwtf.port}";
            };
            "www.${config.variables.domain}" = {
              service = "http://localhost:${builtins.toString config.services.wyattwtf.port}";
            };
            "immich.${config.variables.domain}" = {
              service = "http://localhost:${builtins.toString config.services.immich.port}";
            };
            "filebrowser.${config.variables.domain}" = {
              service = "http://localhost:${builtins.toString config.services.filebrowser.settings.port}";
            };
            "bin.${config.variables.domain}" = {
              service = "http://localhost:${builtins.toString config.services.microbin.settings.MICROBIN_PORT}";
            };
            "syncthing.${config.variables.domain}" = {
              service = "http://${builtins.toString config.services.syncthing.guiAddress}";
            };
          };
          default = "http_status:404";
        };
      };
    };
  };
}
