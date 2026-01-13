{ config, ... }:
let
  rootDir = "${config.storageDir}/filebrowser";
in
{
  services.filebrowser = {
    enable = true;
    openFirewall = true;
    settings = {
      address = config.variables.homelab.wireguard.ip;
      port = 8789;
      root = rootDir;
    };
  };
}
