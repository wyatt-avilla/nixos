{ lib, config, ... }:
{
  options.storage_dir = lib.mkOption {
    type = lib.types.str;
    default = "/mnt/sandisk_2tb/storage";
  };

  config = {
    services.btrfs.autoScrub.enable = true;

    users.users.syncthing.extraGroups = [ "storage-users" ];

    systemd.tmpfiles.rules = [
      "d ${config.storage_dir} 0755 root root -"
      "d ${config.storage_dir}/syncthing 0770 syncthing storage-users -"
    ];
  };
}
