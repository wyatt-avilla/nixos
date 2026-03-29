{ lib, ... }:
{
  imports = [
    ./backup.nix
    ./group.nix
    ./permissions.nix
  ];

  options.storageDir = lib.mkOption {
    type = lib.types.str;
    default = "/mnt/sandisk_2tb/storage";
  };

  config = {
    services.btrfs.autoScrub.enable = true;
  };
}
