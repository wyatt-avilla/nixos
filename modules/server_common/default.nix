{ pkgs, ... }:
{
  imports = [
    ./ssh.nix
    ./sops.nix
  ];

  environment.systemPackages = with pkgs; [ btop ];
}
