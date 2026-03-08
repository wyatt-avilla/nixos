{ inputs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../modules/server-common
    ../../modules/common.nix
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
    grub.devices = lib.mkForce [ "/dev/vda" ];
  };

  # root SSH access needed for nixos-anywhere nixos-rebuild step
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";
  users.users.root.openssh.authorizedKeys.keys = [
    inputs.nix-secrets.nixosModules.plainSecrets.desktop.ssh.publicKey
  ];

  system.stateVersion = "26.05";
}
