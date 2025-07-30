{
  imports = [
    ../../modules/common.nix
    ../../modules/gui_common.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "puriel";

  boot = {
    kernelParams = [
      "video=1920x1080"
      "console=tty2"
    ];
  };

  system.stateVersion = "24.11";
}
