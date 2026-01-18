{
  imports = [
    ../../modules/common.nix
    ../../modules/gui-common
    ./hardware-configuration.nix
  ];

  networking.hostName = "zadkiel";

  boot = {
    kernelParams = [
      "video=1366x768"
      "iomem=relaxed"
    ];

    initrd = {
      kernelModules = [ "i915" ];

      luks.devices."luks-75b4a33a-a4f4-4b61-bb4a-b6260eb04a43".device =
        "/dev/disk/by-uuid/75b4a33a-a4f4-4b61-bb4a-b6260eb04a43";
    };
  };

  services = {
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
