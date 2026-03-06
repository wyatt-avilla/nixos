{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../modules/server-common
    ../../modules/common.nix
    ./wireguard.nix
    ./oauth2-proxy.nix
    ./nginx.nix
    ./ssh-proxy.nix
  ];

  networking.hostName = "ambriel";

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = lib.mkForce false;
  };

  networking.networkmanager.enable = true;
  system.stateVersion = "26.05";
}
