{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
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
  };

  system.stateVersion = "24.11";
}
