{ lib, ... }:
{
  options.variables = {
    vps.wireguard = {
      ip = lib.mkOption {
        type = lib.types.str;
        default = "10.0.0.1";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 51820;
      };
    };

    homelab.wireguard.ip = lib.mkOption {
      type = lib.types.str;
      default = "10.0.0.2";
    };
  };
}
