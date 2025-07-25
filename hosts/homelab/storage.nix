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
      privatebin.group = "storage";
    };

    systemd = {
      tmpfiles.rules = [
        "d ${config.storageDir} 0770 root storage -"
        "d ${config.storageDir}/syncthing 0770 syncthing storage -"
        "d ${config.storageDir}/immich 0770 immich storage -"
        "d ${config.storageDir}/filebrowser 0770 filebrowser storage -"
        "d ${config.storageDir}/privatebin 0770 privatebin storage -"
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

            chown privatebin:storage "${config.storageDir}/privatebin"
            chmod 0770 "${config.storageDir}/privatebin"
          '';
        };
      };
    };
  };
}
