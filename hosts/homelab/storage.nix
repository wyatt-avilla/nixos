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

    systemd = {
      tmpfiles.rules = [
        "d ${config.storageDir} 0755 root root -"
        "d ${config.storageDir}/syncthing 0700 syncthing syncthing -"
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

            chown syncthing:syncthing "${config.storageDir}/syncthing"
            chmod 0700 "${config.storageDir}/syncthing"
          '';
        };
      };
    };
  };
}
