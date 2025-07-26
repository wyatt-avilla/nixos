{ config, ... }:
let
  port = 2233;
  dir = "${config.storageDir}/microbin";
in
{
  services.microbin = {
    enable = true;
    settings = {
      MICROBIN_BIND = "0.0.0.0";
      MICROBIN_PORT = port;
      MICROBIN_DATA_DIR = dir;
      MICROBIN_HIDE_LOGO = true;
      MICROBIN_HIGHLIGHTSYNTAX = true;
      MICROBIN_HIDE_HEADER = true;
      MICROBIN_HIDE_FOOTER = true;
    };
  };

  users.groups.microbin = { };
  users.users.microbin = {
    isSystemUser = true;
    group = "microbin";
  };

  systemd.services.microbin = {
    serviceConfig = {
      User = "microbin";
      Group = "microbin";
    };
  };
}
