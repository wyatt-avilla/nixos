{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../../modules/common.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "zadkiel";

  boot = {
    loader.grub = {
      enable = true;
      device = "/dev/sda";
      useOSProber = false;
      enableCryptodisk = true;
    };

    kernelParams = [ "video=1366x768" ];

    initrd.luks.devices."luks-e9cd8227-d981-4a2b-8347-cc5a777edc68".keyFile =
      "/boot/crypto_keyfile.bin";
    initrd.secrets = {
      "/boot/crypto_keyfile.bin" = null;
    };
  };

  services = {
    xserver.xkb = {
      layout = "us";
      variant = "";
    };

    fprintd.enable = true;
  };

  system.stateVersion = "25.05";
}
