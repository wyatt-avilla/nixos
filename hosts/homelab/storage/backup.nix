{
  config,
  lib,
  pkgs,
  ...
}:
let
  immichDbName = config.services.immich.database.name;
  immichSourceSubvolume = "${config.storageDir}/immich";
  immichBackupRoot = "${config.backupDir}/immich";
  immichBackupDbDir = "${immichBackupRoot}/db";
  immichSourceSnapshotDir = "${sourceSnapshotRoot}/immich";
  immichBackupSnapshotDir = "${immichBackupRoot}/snapshots";

  filebrowserSourceSubvolume = "${config.storageDir}/filebrowser";
  filebrowserBackupRoot = "${config.backupDir}/filebrowser";
  filebrowserSourceSnapshotDir = "${sourceSnapshotRoot}/filebrowser";
  filebrowserBackupSnapshotDir = "${filebrowserBackupRoot}/snapshots";

  sourceSnapshotRoot = "${config.storageDir}/.snapshots";
  pgDump = lib.getExe' config.services.postgresql.package "pg_dump";
  runuser = lib.getExe' pkgs.util-linux "runuser";
  btrfs = lib.getExe' pkgs.btrfs-progs "btrfs";
in
{
  config = lib.mkIf (config.services.immich.enable || config.services.filebrowser.enable) {
    systemd = {
      tmpfiles.rules = [
        "d ${sourceSnapshotRoot} 0770 root storage -"
      ]
      ++ lib.optionals config.services.immich.enable [
        "d ${immichBackupRoot} 0770 root storage -"
        "d ${immichSourceSnapshotDir} 0770 root storage -"
        "d ${immichBackupSnapshotDir} 0770 root storage -"
      ]
      ++ lib.optionals config.services.immich.database.enable [
        "d ${immichBackupDbDir} 0770 root storage -"
      ]
      ++ lib.optionals config.services.filebrowser.enable [
        "d ${filebrowserBackupRoot} 0770 root storage -"
        "d ${filebrowserSourceSnapshotDir} 0770 root storage -"
        "d ${filebrowserBackupSnapshotDir} 0770 root storage -"
      ];

      services =
        lib.optionalAttrs config.services.immich.database.enable {
          "immich-db-backup" = {
            description = "Backup the Immich PostgreSQL database";
            after = [ "postgresql.service" ];
            requires = [ "postgresql.service" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "immich-db-backup" ''
                set -euo pipefail

                dest_dir="${immichBackupDbDir}"
                timestamp="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
                tmp_file="$dest_dir/immich-$timestamp.dump.tmp"
                final_file="$dest_dir/immich-$timestamp.dump"

                mkdir -p "$dest_dir"

                ${runuser} -u postgres -- \
                  ${pgDump} \
                  --format=custom \
                  --dbname=${lib.escapeShellArg immichDbName} \
                  > "$tmp_file"

                chgrp storage "$tmp_file"
                chmod 0640 "$tmp_file"
                mv "$tmp_file" "$final_file"

                ls -1t "$dest_dir"/immich-*.dump 2>/dev/null | tail -n +15 | xargs -r rm -f
              '';
            };
            path = with pkgs; [ coreutils ];
          };
        }
        // {
          "immich-media-backup" = {
            description = "Replicate the Immich media subvolume to the backup drive";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "immich-media-backup" ''
                set -euo pipefail

                source_subvolume="${immichSourceSubvolume}"
                source_snapshot_dir="${immichSourceSnapshotDir}"
                backup_snapshot_dir="${immichBackupSnapshotDir}"
                timestamp="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
                snapshot_name="immich-$timestamp"
                new_snapshot="$source_snapshot_dir/$snapshot_name"

                if ! ${btrfs} subvolume show "$source_subvolume" >/dev/null 2>&1; then
                  echo "Immich media path is not a btrfs subvolume: $source_subvolume" >&2
                  exit 1
                fi

                mkdir -p "$source_snapshot_dir" "$backup_snapshot_dir"

                ${btrfs} subvolume snapshot -r "$source_subvolume" "$new_snapshot"

                latest_common_snapshot="$(
                  (
                    cd "$backup_snapshot_dir"
                    ls -1 immich-* 2>/dev/null || true
                  ) | sort | while read -r candidate; do
                    if [ -n "$candidate" ] && [ -e "$source_snapshot_dir/$candidate" ]; then
                      printf '%s\n' "$candidate"
                    fi
                  done | tail -n 1
                )"

                if [ -n "$latest_common_snapshot" ]; then
                  ${btrfs} send \
                    -p "$source_snapshot_dir/$latest_common_snapshot" \
                    "$new_snapshot" \
                    | ${btrfs} receive "$backup_snapshot_dir"
                else
                  ${btrfs} send "$new_snapshot" | ${btrfs} receive "$backup_snapshot_dir"
                fi

                ls -1dt "$source_snapshot_dir"/immich-* 2>/dev/null | tail -n +8 | while read -r old_snapshot; do
                  ${btrfs} subvolume delete "$old_snapshot"
                done

                ls -1dt "$backup_snapshot_dir"/immich-* 2>/dev/null | tail -n +8 | while read -r old_snapshot; do
                  ${btrfs} subvolume delete "$old_snapshot"
                done
              '';
            };
            path = with pkgs; [ coreutils ];
          };
        }
        // lib.optionalAttrs config.services.filebrowser.enable {
          "filebrowser-backup" = {
            description = "Replicate the FileBrowser subvolume to the backup drive";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "filebrowser-backup" ''
                set -euo pipefail

                source_subvolume="${filebrowserSourceSubvolume}"
                source_snapshot_dir="${filebrowserSourceSnapshotDir}"
                backup_snapshot_dir="${filebrowserBackupSnapshotDir}"
                timestamp="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
                snapshot_name="filebrowser-$timestamp"
                new_snapshot="$source_snapshot_dir/$snapshot_name"

                if ! ${btrfs} subvolume show "$source_subvolume" >/dev/null 2>&1; then
                  echo "FileBrowser path is not a btrfs subvolume: $source_subvolume" >&2
                  exit 1
                fi

                mkdir -p "$source_snapshot_dir" "$backup_snapshot_dir"

                ${btrfs} subvolume snapshot -r "$source_subvolume" "$new_snapshot"

                latest_common_snapshot="$(
                  (
                    cd "$backup_snapshot_dir"
                    ls -1 filebrowser-* 2>/dev/null || true
                  ) | sort | while read -r candidate; do
                    if [ -n "$candidate" ] && [ -e "$source_snapshot_dir/$candidate" ]; then
                      printf '%s\n' "$candidate"
                    fi
                  done | tail -n 1
                )"

                if [ -n "$latest_common_snapshot" ]; then
                  ${btrfs} send \
                    -p "$source_snapshot_dir/$latest_common_snapshot" \
                    "$new_snapshot" \
                    | ${btrfs} receive "$backup_snapshot_dir"
                else
                  ${btrfs} send "$new_snapshot" | ${btrfs} receive "$backup_snapshot_dir"
                fi

                ls -1dt "$source_snapshot_dir"/filebrowser-* 2>/dev/null | tail -n +8 | while read -r old_snapshot; do
                  ${btrfs} subvolume delete "$old_snapshot"
                done

                ls -1dt "$backup_snapshot_dir"/filebrowser-* 2>/dev/null | tail -n +8 | while read -r old_snapshot; do
                  ${btrfs} subvolume delete "$old_snapshot"
                done
              '';
            };
            path = with pkgs; [ coreutils ];
          };
        };

      timers =
        lib.optionalAttrs config.services.immich.database.enable {
          "immich-db-backup" = {
            description = "Run Immich PostgreSQL backups daily";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "daily";
              RandomizedDelaySec = "30m";
              Persistent = true;
            };
          };
        }
        // {
          "immich-media-backup" = {
            description = "Replicate Immich media snapshots daily";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "*-*-* 01:00:00";
              Persistent = true;
            };
          };
        }
        // lib.optionalAttrs config.services.filebrowser.enable {
          "filebrowser-backup" = {
            description = "Replicate FileBrowser snapshots daily";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "*-*-* 01:30:00";
              Persistent = true;
            };
          };
        };
    };
  };
}
