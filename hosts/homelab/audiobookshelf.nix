{ config, ... }:
{
  services.audiobookshelf = {
    enable = true;
    port = 9981;
    dataDir = "${config.storageDir}/audiobookshelf";

    openFirewall = true; # TODO: change
  };
}
