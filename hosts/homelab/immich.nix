{ config, ... }:
{
  services.immich = {
    enable = true;
    openFirewall = true;
    accelerationDevices = null;
    mediaLocation = "${config.storageDir}/immich";
    host = config.variables.homelab.wireguard.ip;
    inherit (config.variables.immich) port;
    settings.server.externalDomain = "https://immich.${config.variables.domain}";
  };

  users.users.immich.extraGroups = [
    "video"
    "render"
  ];
}
