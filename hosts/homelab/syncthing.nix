{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  syncthingDir = "/var/lib/syncthing";
in
{
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    settings = {
      devices = {
        desktop.id = inputs.nix-secrets.nixosModules.plainSecrets.desktop.syncthing.deviceId;
      };

      folders = {
        test_folder = {
          path = "${syncthingDir}/test_folder";
          devices = [ "desktop" ];
        };
      };
    };
  };

  systemd = {
    services.syncthing.environment.STNODEFAULTFOLDER = "true";
  };
}
