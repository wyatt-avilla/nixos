{ config, ... }:
{
  services.immich = {
    enable = true;
    openFirewall = true;
    accelerationDevices = null;
    mediaLocation = "${config.storageDir}/immich";
    host = "0.0.0.0";
    port = 2283;
  };

  users.users.immich.extraGroups = [
    "video"
    "render"
  ];
}
