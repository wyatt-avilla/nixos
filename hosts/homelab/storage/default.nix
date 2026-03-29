{ lib, ... }:
{
  imports = [
    ./backup.nix
    ./group.nix
    ./permissions.nix
    ./subvolumes.nix
  ];

  options.storageDir = lib.mkOption {
    type = lib.types.str;
    default = "/mnt/sandisk_2tb/storage";
  };

  options.backupDir = lib.mkOption {
    type = lib.types.str;
    default = "/mnt/wd_red_plus_4tb/backups";
  };

  config = {
    services.btrfs.autoScrub.enable = true;
  };
}
