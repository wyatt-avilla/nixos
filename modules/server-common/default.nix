{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./ssh.nix
    ./sops.nix
    ./wireguard.nix
    ./service-variables.nix
    ./observability.nix
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
    default = inputs.nix-secrets.nixosModules.plainSecrets.domain.personal;
  };
}
