{ config, ... }:
{
  services.immich = {
    enable = true;
    openFirewall = true;
    accelerationDevices = null;
    mediaLocation = "${config.storageDir}/immich";
    port = 2283;
  };

  users.users.immich.extraGroups = [
    "video"
    "render"
  ];
}
