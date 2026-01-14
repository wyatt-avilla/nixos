{ config, lib, ... }:
let
  inherit (config.variables.microbin) port;
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
      MICROBIN_PRIVATE = true;
      MICROBIN_QR = true;
      MICROBIN_ETERNAL_PASTA = true;
      MICROBIN_MAX_FILE_SIZE_ENCRYPTED_MB = 1000 * 10;
      MICROBIN_MAX_FILE_SIZE_UNENCRYPTED_MB = 1000 * 10;
      MICROBIN_PUBLIC_PATH = "https://bin.${config.variables.domain}";
    };
  };

  users.groups.microbin = { };
  users.users.microbin = {
    isSystemUser = true;
    group = "microbin";
  };

  systemd.services.microbin = {
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "microbin";
      Group = "microbin";
    };
  };
}
