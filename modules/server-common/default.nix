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

    # Switching implementations requires a reboot, so keep server deploys on
    # the implementation used before the nixpkgs 26.11 update.
    services.dbus.implementation = "dbus";

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
