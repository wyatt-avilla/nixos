{ config, ... }:
let
  rootDir = "${config.storageDir}/filebrowser";
  databaseFile = "${rootDir}/.filebrowser/database.db";
in
{
  services.filebrowser = {
    enable = true;
    openFirewall = true;
    settings = {
      address = config.variables.homelab.wireguard.ip;
      inherit (config.variables.filebrowser) port;
      root = rootDir;
      database = databaseFile;
    };
  };
}
