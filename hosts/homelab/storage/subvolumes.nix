{
  config,
  lib,
  pkgs,
  ...
}:
let
  btrfs = lib.getExe' pkgs.btrfs-progs "btrfs";
  chown = lib.getExe' pkgs.coreutils "chown";
  chmod = lib.getExe' pkgs.coreutils "chmod";
in
{
  systemd.services."ensure-storage-subvolumes" = {
    description = "Ensure required storage subvolumes exist";
    after = [ "local-fs.target" ];
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
            echo "Refusing to replace existing non-subvolume at $path" >&2
            exit 1
          fi

          ${btrfs} subvolume create "$path"
          ${chown} "$owner:$group" "$path"
          ${chmod} "$mode" "$path"
        }

        ensure_subvolume "${config.storageDir}/immich" immich storage 0770
      '';
    };
  };
}
