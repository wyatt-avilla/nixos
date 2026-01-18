{ pkgs, ... }:
{
  imports = [
    ./login.nix
    ./docker.nix
  ];

  environment.systemPackages = with pkgs; [ home-manager ];

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  networking = {
    firewall.allowedTCPPorts = [ 57621 ]; # spotify local files
    firewall.allowedUDPPorts = [ 5353 ]; # spotify cast
  };

  users.users.wyatt = {
    extraGroups = [ "dialout" ];
  };
}
