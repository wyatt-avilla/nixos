{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/server_common
    ../../modules/common.nix
    ./wireguard.nix
    ./oauth2-proxy.nix
  ];

  networking.hostName = "ambriel";

  boot.loader = {
    systemd-boot.enable = lib.mkForce false;
    efi.canTouchEfiVariables = lib.mkForce false;
    grub = {
      enable = true;
      device = "/dev/vda";
    };
  };

  networking.networkmanager.enable = true;
  system.stateVersion = "26.05";
}
