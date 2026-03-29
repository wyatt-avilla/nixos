{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (config.storage) directories;
  dataPaths = config.storage.paths.data;

  directoryRules = builtins.map (
    name:
    let
      directory = directories.${name};
    in
    "d ${dataPaths.${name}} ${directory.mode} ${directory.owner} ${directory.group} -"
  ) (builtins.attrNames directories);

  linkRules = builtins.map (
    link: "L+ ${dataPaths.${link.parent}}/${link.name} - - - - ${dataPaths.${link.target}}"
  ) config.storage.links;

  directoryFixups = lib.concatMapStrings (
    name:
    let
      directory = directories.${name};
    in
    ''
      chown ${directory.owner}:${directory.group} "${dataPaths.${name}}"
      chmod ${directory.mode} "${dataPaths.${name}}"
    ''
  ) (builtins.attrNames directories);
in
{
  systemd = {
    tmpfiles.rules = [
      "d ${config.storage.paths.root} 0770 root storage -"
      "d ${config.storage.paths.backupRoot} 0770 root storage -"
    ]
    ++ directoryRules
    ++ linkRules;

    services."fix-storage-dir-perms" = {
      description = "Ensure correct permissions for storage directories";
      after = [ "local-fs.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "fix-storage-dir-perms" ''
          set -e
          chown root:storage "${config.storage.paths.root}"
          chmod 0770 "${config.storage.paths.root}"
          chown root:storage "${config.storage.paths.backupRoot}"
          chmod 0770 "${config.storage.paths.backupRoot}"

          ${directoryFixups}
        '';
      };
    };
  };
}
