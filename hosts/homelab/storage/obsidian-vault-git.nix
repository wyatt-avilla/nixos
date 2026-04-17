{
  config,
  lib,
  pkgs,
  ...
}:
let
  sourceDir = "${config.storage.paths.data.syncthing}/notes";
  destDir = "${config.storage.paths.backupRoot}/obsidian-vault-git";
  rsyncExcludes = [
    "/.git/"
    "/.obsidian/workspace.json"
    "/.obsidian/workspace-mobile.json"
    "/.obsidian/cache"
    "/.obsidian/graph.json"
  ];
  rsyncExcludeArgs = lib.concatMapStringsSep " " (
    exclude: "--exclude=${lib.escapeShellArg exclude}"
  ) rsyncExcludes;

  git = lib.getExe pkgs.git;
  rsync = lib.getExe pkgs.rsync;
  date = lib.getExe' pkgs.coreutils "date";
  mkdir = lib.getExe' pkgs.coreutils "mkdir";
in
{
  systemd = {
    tmpfiles.rules = [
      "d ${destDir} 0770 ${config.services.syncthing.user} ${config.services.syncthing.group} -"
    ];

    services.obsidian-vault-git = {
      description = "Commit a nightly Git mirror of the Obsidian vault";
      after = [ "syncthing.service" ];
      unitConfig.RequiresMountsFor = [
        sourceDir
        destDir
      ];

      serviceConfig = {
        Type = "oneshot";
        User = config.services.syncthing.user;
        Group = config.services.syncthing.group;
        UMask = "0007";
        ExecStart = pkgs.writeShellScript "obsidian-vault-git" ''
          set -euo pipefail

          source_dir=${lib.escapeShellArg sourceDir}
          dest_dir=${lib.escapeShellArg destDir}

          if [ ! -d "$source_dir" ]; then
            echo "Obsidian vault source directory is missing: $source_dir" >&2
            exit 1
          fi

          ${mkdir} -p "$dest_dir"

          if [ ! -d "$dest_dir/.git" ]; then
            ${git} -C "$dest_dir" init --initial-branch=main
          fi

          ${git} -C "$dest_dir" config user.name "Obsidian Vault Git"
          ${git} -C "$dest_dir" config user.email "obsidian-vault-git@barachiel.local"
          ${git} -C "$dest_dir" config commit.gpgSign false

          ${rsync} -a --delete ${rsyncExcludeArgs} "$source_dir"/ "$dest_dir"/

          ${git} -C "$dest_dir" add -A

          if ! ${git} -C "$dest_dir" diff --cached --quiet --exit-code; then
            timestamp="$(${date} --iso-8601=seconds)"
            ${git} -C "$dest_dir" commit -m "Obsidian vault git backup $timestamp"
          fi
        '';
      };
    };

    timers.obsidian-vault-git = {
      description = "Run Obsidian vault Git backup nightly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 04:00:00";
        RandomizedDelaySec = "30m";
        Persistent = true;
      };
    };
  };
}
