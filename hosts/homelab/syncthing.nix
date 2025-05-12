{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  syncthingDir = "${config.storageDir}/syncthing";
in
{
  networking = {
    firewall.allowedTCPPorts = [ 8384 ];
    firewall.allowedUDPPorts = [ 8384 ];
  };

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    guiAddress = "0.0.0.0:8384";
    settings = {
      devices = {
        desktop.id = inputs.nix-secrets.nixosModules.plainSecrets.desktop.syncthing.deviceId;
      };

      folders = {
        misc = {
          path = "${syncthingDir}/misc";
          devices = [ "desktop" ];
        };
      };
    };
  };

  systemd = {
    services.syncthing.environment.STNODEFAULTFOLDER = "true";
  };
}
