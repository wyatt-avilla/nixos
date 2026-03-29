{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  inherit (config.storage) backupDisk;
  backupMountUnit = "${utils.escapeSystemdPath backupDisk.mountPoint}.mount";
  idleSeconds = toString (backupDisk.spindownMinutes * 60);
in
{
  config = {
    systemd.services.storage-backup-disk-spindown = {
      description = "Spin down the backup disk after inactivity";
      wantedBy = [ "multi-user.target" ];
      after = [
        "local-fs.target"
        backupMountUnit
      ];
      requires = [ backupMountUnit ];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "10s";
        ExecStartPre = pkgs.writeShellScript "storage-backup-disk-spindown-preflight" ''
          set -euo pipefail

          device=${lib.escapeShellArg backupDisk.deviceById}

          if [ ! -b "$device" ]; then
            echo "backup disk device is missing or not a block device: $device" >&2
            exit 1
          fi
        '';
        ExecStart = ''
          ${lib.getExe pkgs.hd-idle} \
            -i 0 \
            -c ata \
            -a ${lib.escapeShellArg backupDisk.deviceById} \
            -i ${idleSeconds} \
            -s 1
        '';
      };
    };
  };
}
