{ pkgs, ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/server-common
    ./hardware-configuration.nix
    ./syncthing.nix
    ./storage.nix
    ./filebrowser.nix
    ./immich.nix
    ./microbin.nix
    ./cloudflared.nix
    ./claude-discord-bot.nix
    ./wyattwtf.nix
    ./wireguard.nix
    ./audiobookshelf.nix
  ];

  networking.hostName = "barachiel";

  environment.systemPackages = with pkgs; [
    vim
    btop
  ];

  system.stateVersion = "24.11";
}
