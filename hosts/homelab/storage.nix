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

    services.syncthing.group = "storage";
    users.users.filebrowser.group = "storage";

    systemd = {
      tmpfiles.rules = [
        "d ${config.storageDir} 0755 root storage -"
        "d ${config.storageDir}/syncthing 0760 syncthing storage -"
      ];

      services.filebrowser.serviceConfig.group = "storage";

      services."fix-storage-dir-perms" = {
        description = "Ensure correct permissions for storage directories";
        after = [ "local-fs.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "fix-storage-dir-perms" ''
            set -e
            chown root:storage "${config.storageDir}"
            chmod 0755 "${config.storageDir}"

            chown syncthing:storage "${config.storageDir}/syncthing"
            chmod 0760 "${config.storageDir}/syncthing"
          '';
        };
      };
    };
  };
}
