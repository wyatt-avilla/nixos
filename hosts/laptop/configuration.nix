{ config, pkgs, ... }:

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
  };

  system.stateVersion = "25.05";
}
