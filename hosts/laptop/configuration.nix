{ pkgs, ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/gui-common
    ./hardware-configuration.nix
  ];

  networking.hostName = "zadkiel";

  hardware.graphics = {
    extraPackages = with pkgs; [ intel-vaapi-driver ];
  };

  # Sandy Bridge predates intel-media-driver/iHD; keep VA-API on i965.
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "i965";
  };

  boot = {
    kernelParams = [ "iomem=relaxed" ];

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
        CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
        CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";

        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";

        DEVICES_TO_DISABLE_ON_STARTUP = "bluetooth";
        DEVICES_TO_DISABLE_ON_BAT_NOT_IN_USE = "bluetooth";

        START_CHARGE_THRESH_BAT0 = 75;
        STOP_CHARGE_THRESH_BAT0 = 80;
      };
    };
  };

  system.stateVersion = "25.05";
}
