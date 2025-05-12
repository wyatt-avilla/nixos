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

    users = {
      groups.storage-users.members = [ "syncthing" ];
    };

    systemd = {
      tmpfiles.rules = [
        "d ${config.storageDir} 0755 root root -"
        "d ${config.storageDir}/syncthing 0770 syncthing storage-users -"
      ];

      services."fix-storage-dir-perms" = {
        description = "Ensure correct permissions for storage directories";
        after = [ "local-fs.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "fix-storage-dir-perms" ''
            set -e
            chown root:root "${config.storageDir}"
            chmod 0755 "${config.storageDir}"

            chown syncthing:storage-users "${config.storageDir}/syncthing"
            chmod 0770 "${config.storageDir}/syncthing"
          '';
        };
      };
    };
  };
}
