{
  inputs,
  config,
  lib,
  pkgs,
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

  networking.hostName = "puriel";

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 0;
    };

    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [
      "console=tty2"
      "boot.shell_on_fail"
      "quiet"
      "video=1920x1080"
    ];
  };

  services = {
    xserver.xkb = {
      layout = "us";
      variant = "";
    };

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

  system.stateVersion = "24.11";
}
