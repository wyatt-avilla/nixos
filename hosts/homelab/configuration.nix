{ pkgs, ... }:
{
  imports = [
    ../../modules/common.nix
    ./hardware-configuration.nix
    ./sops.nix
    ./ssh.nix
    ./syncthing.nix
    ./storage.nix
    ./filebrowser.nix
    ./immich.nix
    ./microbin.nix
    ./cloudflared.nix
  ];

  networking.hostName = "barachiel";

  environment.systemPackages = with pkgs; [
    vim
    btop
  ];

  system.stateVersion = "24.11";
}
