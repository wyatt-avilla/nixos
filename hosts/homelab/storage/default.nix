{ lib, config, ... }:
let
  backupDiskMountPoint = dirOf config.backupDir;
  directories = {
    syncthing = {
      owner = "syncthing";
      group = "storage";
      mode = "0770";
      assignServiceGroup = true;
      ensureSubvolume = false;
      backup = null;
    };

    immich = {
      owner = "immich";
      group = "storage";
      mode = "0770";
      assignServiceGroup = true;
      ensureSubvolume = true;
      backup = {
        snapshot = {
          timer = "Sun 01:00:00";
          retention = 3;
        };
        database = {
          timer = "Sun 00:30:00";
          retention = 3;
        };
      };
    };

    filebrowser = {
      owner = "filebrowser";
      group = "storage";
      mode = "0770";
      assignServiceGroup = true;
      ensureSubvolume = true;
      backup = {
        snapshot = {
          timer = "Sun 01:30:00";
          retention = 3;
        };
      };
    };

    microbin = {
      owner = "microbin";
      group = "storage";
      mode = "0770";
      assignServiceGroup = false;
      ensureSubvolume = false;
      backup = null;
    };

    audiobookshelf = {
      owner = "audiobookshelf";
      group = "storage";
      mode = "0770";
      assignServiceGroup = true;
      ensureSubvolume = false;
      backup = null;
    };
  };

  snapshotRoot = "${config.storageDir}/.snapshots";
in
{
  imports = [
    ./backup.nix
    ./group.nix
    ./permissions.nix
    ./spindown.nix
    ./subvolumes.nix
  ];

  options = {
    storageDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/sandisk_2tb/storage";
    };

    backupDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/wd_red_plus_4tb/backups";
    };

    storage = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      readOnly = true;
    };
  };

  config = {
    storage = {
      inherit directories;

      backupDisk = {
        deviceById = "/dev/disk/by-id/ata-WDC_WD40EFZZ-68CPAN0_WD-WX42DA59T1UC";
        mountPoint = backupDiskMountPoint;
        spindownMinutes = 5;
      };

      links = [
        {
          parent = "filebrowser";
          name = "syncthing";
          target = "syncthing";
        }
        {
          parent = "filebrowser";
          name = "audiobookshelf";
          target = "audiobookshelf";
        }
      ];

      paths = {
        root = config.storageDir;
        backupRoot = config.backupDir;
        inherit snapshotRoot;
        data = lib.mapAttrs (name: _: "${config.storageDir}/${name}") directories;
        backup = lib.mapAttrs (name: _: "${config.backupDir}/${name}") directories;
        snapshot = lib.mapAttrs (name: _: "${snapshotRoot}/${name}") directories;
        backupSnapshot = lib.mapAttrs (name: _: "${config.backupDir}/${name}/snapshots") directories;
      };
    };

    services.btrfs.autoScrub.enable = true;
  };
}
