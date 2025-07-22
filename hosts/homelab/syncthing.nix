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
    settings = {
      devices = {
        desktop.id = inputs.nix-secrets.nixosModules.plainSecrets.desktop.syncthing.deviceId;
        laptop.id = inputs.nix-secrets.nixosModules.plainSecrets.laptop.syncthing.deviceId;
        phone.id = inputs.nix-secrets.nixosModules.plainSecrets.phone.syncthing.deviceId;
        boox.id = inputs.nix-secrets.nixosModules.plainSecrets.boox.syncthing.deviceId;
      };

      folders = {
        misc = {
          path = "${syncthingDir}/misc";
          devices = [
            "desktop"
            "laptop"
          ];
        };

        pictures = {
          path = "${syncthingDir}/pictures";
          devices = [
            "desktop"
            "laptop"
          ];
        };

        music = {
          path = "${syncthingDir}/music";
          devices = [ "desktop" ];
        };

        documents = {
          path = "${syncthingDir}/documents";
          devices = [
            "desktop"
            "laptop"
          ];
        };

        books = {
          path = "${syncthingDir}/books";
          devices = [
            "desktop"
            "boox"
          ];
        };

        notes = {
          path = "${syncthingDir}/notes";
          devices = [
            "desktop"
            "laptop"
            "boox"
            "phone"
          ];
        };
      };
    };
  };

  systemd = {
    services.syncthing.environment.STNODEFAULTFOLDER = "true";
  };
}
