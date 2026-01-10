{ pkgs, ... }:
{
  imports = [
    ../../modules/common.nix
    ./hardware-configuration.nix
    ../../modules/server_common
  ];

  networking.hostName = "ambriel";

  environment.systemPackages = with pkgs; [
    vim
    btop
  ];

  system.stateVersion = "25.11";
}
