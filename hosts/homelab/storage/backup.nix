{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.storage) directories;
  inherit (config.storage) paths;
  snapshotBackups = lib.filterAttrs (
    _: directory: directory.backup != null && directory.backup ? snapshot
  ) directories;
  immichDatabaseBackupEnabled =
    config.services.immich.enable
    && config.services.immich.database.enable
    && directories.immich.backup != null
    && directories.immich.backup ? database;

  pgDump = lib.getExe' config.services.postgresql.package "pg_dump";
  runuser = lib.getExe' pkgs.util-linux "runuser";
  btrfs = lib.getExe' pkgs.btrfs-progs "btrfs";

  snapshotTmpfileRules = lib.concatLists (
    lib.mapAttrsToList (name: _: [
      "d ${paths.backup.${name}} 0770 root storage -"
      "d ${paths.snapshot.${name}} 0770 root storage -"
      "d ${paths.backupSnapshot.${name}} 0770 root storage -"
    ]) snapshotBackups
  );

  mkSnapshotBackupService =
    name: directory:
    let
      retentionCutoff = toString (directory.backup.snapshot.retention + 1);
    in
    {
      description = "Replicate the ${name} subvolume to the backup drive";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "${name}-backup" ''
          set -euo pipefail

          source_subvolume="${paths.data.${name}}"
          source_snapshot_dir="${paths.snapshot.${name}}"
          backup_snapshot_dir="${paths.backupSnapshot.${name}}"
          timestamp="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
          snapshot_name="${name}-$timestamp"
          new_snapshot="$source_snapshot_dir/$snapshot_name"

          if ! ${btrfs} subvolume show "$source_subvolume" >/dev/null 2>&1; then
            echo "${name} path is not a btrfs subvolume: $source_subvolume" >&2
            exit 1
          fi

          mkdir -p "$source_snapshot_dir" "$backup_snapshot_dir"

          ${btrfs} subvolume snapshot -r "$source_subvolume" "$new_snapshot"

          latest_common_snapshot="$(
            (
              cd "$backup_snapshot_dir"
              ls -1 ${name}-* 2>/dev/null || true
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

          ls -1dt "$source_snapshot_dir"/${name}-* 2>/dev/null | tail -n +${retentionCutoff} | while read -r old_snapshot; do
            ${btrfs} subvolume delete "$old_snapshot"
          done

          ls -1dt "$backup_snapshot_dir"/${name}-* 2>/dev/null | tail -n +${retentionCutoff} | while read -r old_snapshot; do
            ${btrfs} subvolume delete "$old_snapshot"
          done
        '';
      };
      path = with pkgs; [ coreutils ];
    };

  snapshotServices = lib.mapAttrs' (
    name: directory: lib.nameValuePair "${name}-backup" (mkSnapshotBackupService name directory)
  ) snapshotBackups;

  snapshotTimers = lib.mapAttrs' (
    name: directory:
    lib.nameValuePair "${name}-backup" {
      description = "Replicate ${name} snapshots weekly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = directory.backup.snapshot.timer;
        Persistent = true;
      };
    }
  ) snapshotBackups;
in
{
  config = lib.mkIf (snapshotBackups != { } || immichDatabaseBackupEnabled) {
    systemd = {
      tmpfiles.rules =
        lib.optionals (snapshotBackups != { }) [
          "d ${paths.snapshotRoot} 0770 root storage -"
        ]
        ++ snapshotTmpfileRules
        ++ lib.optionals immichDatabaseBackupEnabled [
          "d ${paths.backup.immich}/db 0770 root storage -"
        ];

      services =
        snapshotServices
        // lib.optionalAttrs immichDatabaseBackupEnabled {
          "immich-db-backup" = {
            description = "Backup the Immich PostgreSQL database";
            after = [ "postgresql.service" ];
            requires = [ "postgresql.service" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "immich-db-backup" ''
                set -euo pipefail

                dest_dir="${paths.backup.immich}/db"
                timestamp="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
                tmp_file="$dest_dir/immich-$timestamp.dump.tmp"
                final_file="$dest_dir/immich-$timestamp.dump"

                mkdir -p "$dest_dir"

                ${runuser} -u postgres -- \
                  ${pgDump} \
                  --format=custom \
                  --dbname=${lib.escapeShellArg config.services.immich.database.name} \
                  > "$tmp_file"

                chgrp storage "$tmp_file"
                chmod 0640 "$tmp_file"
                mv "$tmp_file" "$final_file"

                ls -1t "$dest_dir"/immich-*.dump 2>/dev/null | tail -n +${
                  toString (directories.immich.backup.database.retention + 1)
                } | xargs -r rm -f
              '';
            };
            path = with pkgs; [ coreutils ];
          };
        };

      timers =
        snapshotTimers
        // lib.optionalAttrs immichDatabaseBackupEnabled {
          "immich-db-backup" = {
            description = "Run Immich PostgreSQL backups weekly";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = directories.immich.backup.database.timer;
              RandomizedDelaySec = "30m";
              Persistent = true;
            };
          };
        };
    };
  };
}
