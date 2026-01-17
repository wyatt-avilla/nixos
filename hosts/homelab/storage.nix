{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.storageDir = lib.mkOption {
    type = lib.types.str;
    default = "/mnt/sandisk_2tb/storage";
  };

  config = {
    services.btrfs.autoScrub.enable = true;

    users.groups.storage = { };

    services = {
      syncthing.group = "storage";
      immich.group = "storage";
      filebrowser.group = "storage";
    };

    users.users = {
      microbin.extraGroups = [ "storage" ];
    };

    systemd = {
      tmpfiles.rules = [
        "d ${config.storageDir} 0770 root storage -"
        "d ${config.storageDir}/syncthing 0770 syncthing storage -"
        "d ${config.storageDir}/immich 0770 immich storage -"
        "d ${config.storageDir}/filebrowser 0770 filebrowser storage -"
        "d ${config.storageDir}/filebrowser/syncthing 0770 syncthing storage -"
        "d ${config.storageDir}/microbin 0770 microbin storage -"
      ];

      services."fix-storage-dir-perms" = {
        description = "Ensure correct permissions for storage directories";
        after = [ "local-fs.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "fix-storage-dir-perms" ''
            set -e
            chown root:storage "${config.storageDir}"
            chmod 0770 "${config.storageDir}"

            chown syncthing:storage "${config.storageDir}/syncthing"
            chmod 0770 "${config.storageDir}/syncthing"

            chown immich:storage "${config.storageDir}/immich"
            chmod 0770 "${config.storageDir}/immich"

            chown filebrowser:storage "${config.storageDir}/filebrowser"
            chmod 0770 "${config.storageDir}/filebrowser"

            chown syncthing:storage "${config.storageDir}/filebrowser/syncthing"
            chmod 0770 "${config.storageDir}/filebrowser/syncthing"

            chown microbin:storage "${config.storageDir}/microbin"
            chmod 0770 "${config.storageDir}/microbin"
          '';
        };
      };
    };
  };
}
