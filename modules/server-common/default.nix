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

    nix.gc = {
      automatic = true;
      dates = "03:15";
      options = "--delete-older-than 1d";
      persistent = true;
    };
  };

  options.variables.domain = lib.mkOption {
    type = lib.types.str;
    default = "wyatt.wtf";
  };
}
