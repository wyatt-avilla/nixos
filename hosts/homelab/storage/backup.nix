{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.services.immich.database) name;
  backupRoot = "${config.backupDir}/immich";
  backupDbDir = "${backupRoot}/db";
  pgDump = lib.getExe' config.services.postgresql.package "pg_dump";
  runuser = lib.getExe' pkgs.util-linux "runuser";
in
{
  config = lib.mkIf (config.services.immich.enable && config.services.immich.database.enable) {
    systemd = {
      tmpfiles.rules = [
        "d ${backupRoot} 0770 root storage -"
        "d ${backupDbDir} 0770 root storage -"
      ];

      services."immich-db-backup" = {
        description = "Backup the Immich PostgreSQL database";
        after = [ "postgresql.service" ];
        requires = [ "postgresql.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "immich-db-backup" ''
            set -euo pipefail

            dest_dir="${backupDbDir}"
            timestamp="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
            tmp_file="$dest_dir/immich-$timestamp.dump.tmp"
            final_file="$dest_dir/immich-$timestamp.dump"

            mkdir -p "$dest_dir"

            ${runuser} -u postgres -- \
              ${pgDump} \
              --format=custom \
              --dbname=${lib.escapeShellArg name} \
              > "$tmp_file"

            chgrp storage "$tmp_file"
            chmod 0640 "$tmp_file"
            mv "$tmp_file" "$final_file"

            ls -1t "$dest_dir"/immich-*.dump 2>/dev/null | tail -n +15 | xargs -r rm -f
          '';
        };
        path = with pkgs; [ coreutils ];
      };

      timers."immich-db-backup" = {
        description = "Run Immich PostgreSQL backups daily";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          RandomizedDelaySec = "30m";
          Persistent = true;
        };
      };
    };
  };
}
