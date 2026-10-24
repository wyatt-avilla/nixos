{
  imports = [
    ../../modules/common.nix
    ../../modules/gui-common
    ./hardware-configuration.nix
  ];

  networking.hostName = "puriel";

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  boot = {
    kernelParams = [
      "video=1920x1080"
      "console=tty2"
    ];
  };

  system.stateVersion = "24.11";
}
