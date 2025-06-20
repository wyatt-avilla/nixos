{
  config,
  pkgs,
  lib,
  ...
}:
let
  screenDimension = "1366x768";
in
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
      timeoutStyle = "hidden";
      splashImage = null;
      gfxmodeBios = screenDimension;
      gfxpayloadBios = "keep";
      enableCryptodisk = true;
    };

    kernelParams = [ "video=${screenDimension}" ];

    initrd = {
      kernelModules = [ "i915" ];

      luks.devices."luks-e9cd8227-d981-4a2b-8347-cc5a777edc68".keyFile = "/boot/crypto_keyfile.bin";
      secrets = {
        "/boot/crypto_keyfile.bin" = null;
      };
    };
  };

  services = {
    xserver.xkb = {
      layout = "us";
      variant = "";
    };

    fprintd.enable = true;

    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      };
    };
  };

  system.stateVersion = "25.05";
}
