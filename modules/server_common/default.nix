{ lib, pkgs, ... }:
{
  imports = [
    ./ssh.nix
    ./sops.nix
    ./wireguard.nix
  ];

  config = {
    environment.systemPackages = with pkgs; [ btop ];
  };

  options.variables.domain = lib.mkOption {
    type = lib.types.str;
    default = "wyatt.wtf";
  };

  options.variables.vps.publicIp = lib.mkOption {
    type = lib.types.str;
    default = "134.199.142.228";
  };
}
