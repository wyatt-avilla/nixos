{ config, ... }:
let
  dir = "${config.storageDir}/privatebin";
in
{
  services.privatebin = {
    enable = true;
    dataDir = dir;
    enableNginx = true;
    virtualHost = "0.0.0.0";

    settings = {
      main = {
        fileupload = true;
        discussion = true;
        qrcode = true;
        email = false;
      };

      expire_options = {
        "5min" = 300;
        "10min" = 600;
        "1hour" = 3600;
        "1day" = 86400;
        "1week" = 604800;
        "1month" = 2592000;
        "1year" = 31536000;
        "never" = 0;
      };

      expire = {
        default = "1week";
      };

      model = {
        class = "Filesystem";
      };

      model_options = { inherit dir; };
    };
  };
}
