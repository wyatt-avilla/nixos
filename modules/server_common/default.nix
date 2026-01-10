{ lib, pkgs, ... }:
{
  imports = [
    ./ssh.nix
    ./sops.nix
  ];

  config = {
    environment.systemPackages = with pkgs; [ btop ];
  };

  options.variables.domain = lib.mkOption {
    type = lib.types.str;
    default = "wyatt.wtf";
  };
}
