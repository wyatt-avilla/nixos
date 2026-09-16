{ lib, pkgs, ... }:
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

  # The dbus-daemon -> dbus-broker transition cannot complete during a live
  # switch. Schedule exactly one reboot after the new generation is selected.
  system.activationScripts.scheduleDbusBrokerMigrationReboot = ''
    marker=/var/lib/nixos/dbus-broker-migration-reboot

    if ${pkgs.procps}/bin/pgrep -x dbus-daemon >/dev/null && [ ! -e "$marker" ]; then
      ${pkgs.systemd}/bin/systemd-run \
        --on-active=10s \
        --unit=dbus-broker-migration-reboot \
        ${pkgs.systemd}/bin/systemctl --force --force reboot
      ${pkgs.coreutils}/bin/install -Dm600 /dev/null "$marker"
    fi
  '';

  system.stateVersion = "26.05";
}
