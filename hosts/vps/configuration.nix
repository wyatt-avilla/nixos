{ pkgs, ... }:
{
  imports = [
    ../../modules/common.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "ambriel";

  environment.systemPackages = with pkgs; [
    vim
    btop
  ];

  system.stateVersion = "25.11";
}
