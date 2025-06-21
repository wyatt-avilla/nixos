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
      "video=1920x1080"
      "console=tty2"
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
