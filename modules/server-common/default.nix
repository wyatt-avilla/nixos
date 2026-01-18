{ lib, pkgs, ... }:
{
  imports = [
    ./ssh.nix
    ./sops.nix
    ./wireguard.nix
    ./service-variables.nix
  ];

  config = {
    environment.systemPackages = with pkgs; [ btop ];
  };

  options.variables.domain = lib.mkOption {
    type = lib.types.str;
    default = "wyatt.wtf";
  };
}
