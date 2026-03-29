{
  config,
  lib,
  pkgs,
  ...
}:
let
  subvolumeDirectories = lib.filterAttrs (
    _: directory: directory.ensureSubvolume
  ) config.storage.directories;
  dataPaths = config.storage.paths.data;
  btrfs = lib.getExe' pkgs.btrfs-progs "btrfs";
  chown = lib.getExe' pkgs.coreutils "chown";
  chmod = lib.getExe' pkgs.coreutils "chmod";
  find = lib.getExe' pkgs.findutils "find";
  rmdir = lib.getExe' pkgs.coreutils "rmdir";
  ensureCommands = lib.concatMapStrings (
    name:
    let
      directory = subvolumeDirectories.${name};
    in
    ''
      ensure_subvolume "${dataPaths.${name}}" ${directory.owner} ${directory.group} ${directory.mode}
    ''
  ) (builtins.attrNames subvolumeDirectories);
in
{
  systemd.services."ensure-storage-subvolumes" = {
    description = "Ensure required storage subvolumes exist";
    after = [ "local-fs.target" ];
    before = [
      "filebrowser.service"
      "fix-storage-dir-perms.service"
      "systemd-tmpfiles-resetup.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "ensure-storage-subvolumes" ''
        set -euo pipefail

        ensure_subvolume() {
          path="$1"
          owner="$2"
          group="$3"
          mode="$4"

          if ${btrfs} subvolume show "$path" >/dev/null 2>&1; then
            return 0
          fi

          if [ -e "$path" ]; then
            if [ -d "$path" ] && [ -z "$(${find} "$path" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
              ${rmdir} "$path"
            else
              echo "Refusing to replace existing non-subvolume at $path" >&2
              exit 1
            fi
          fi

          ${btrfs} subvolume create "$path"
          ${chown} "$owner:$group" "$path"
          ${chmod} "$mode" "$path"
        }

        ${ensureCommands}
      '';
    };
  };
}
