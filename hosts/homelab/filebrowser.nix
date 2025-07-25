{ config, ... }:
let
  rootDir = "${config.storageDir}/filebrowser";
in
{
  services.filebrowser = {
    enable = true;
    openFirewall = true;
    settings = {
      port = 8789;
      root = rootDir;
    };
  };
}
