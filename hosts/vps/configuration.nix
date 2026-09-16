{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/server-common
    ../../modules/common.nix
    ./deploy
    ./do-networking.nix
    ./wireguard.nix
    ./oauth2-proxy.nix
    ./nginx.nix
    ./ssh-proxy.nix
  ];

  networking.hostName = "ambriel";

  boot.loader = {
    systemd-boot.enable = lib.mkForce false;
    efi.canTouchEfiVariables = lib.mkForce false;
    grub.enable = true;
  };

  system.stateVersion = "26.05";
}
