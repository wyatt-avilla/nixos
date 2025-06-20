{
  config,
  pkgs,
  lib,
  ...
}:
let
  tuigreet = "${pkgs.greetd.tuigreet}/bin/tuigreet";
in
{
  imports = [
    ../../modules/common.nix
    ./hardware-configuration.nix
  ];

  boot = {
    loader.grub = {
      enable = true;
      device = "/dev/sda";
      useOSProber = false;
      enableCryptodisk = true;
    };

    initrd.luks.devices."luks-e9cd8227-d981-4a2b-8347-cc5a777edc68".keyFile =
      "/boot/crypto_keyfile.bin";
    initrd.secrets = {
      "/boot/crypto_keyfile.bin" = null;
    };
  };

  networking.hostName = "zadkiel";

  networking.networkmanager.enable = true;

  services = {
    xserver.xkb = {
      layout = "us";
      variant = "";
    };

    fprintd.enable = true;

    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${tuigreet} --time --remember --remember-session --cmd '${lib.getExe pkgs.uwsm} start hyprland-uwsm.desktop > /dev/null'";
          user = "greeter";
        };
      };
    };
  };

  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };

  system.stateVersion = "25.05";
}
