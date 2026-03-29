{ config, lib, ... }:
let
  storageGroupedServices = lib.filterAttrs (
    _: directory: directory.assignServiceGroup
  ) config.storage.directories;
in
{
  users.groups.storage = { };

  services = lib.mapAttrs (_: directory: { inherit (directory) group; }) storageGroupedServices;

  users.users = {
    microbin.extraGroups = [ "storage" ];
  };
}
