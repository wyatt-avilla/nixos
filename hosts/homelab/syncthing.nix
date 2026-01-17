{ config, inputs, ... }:
let
  syncthingDir = "${config.storageDir}/filebrowser/syncthing";
in
{
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    settings = {
      gui = {
        insecureSkipHostcheck = true;
      };

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

  systemd.services.syncthing = {
    environment.STNODEFAULTFOLDER = "true";
    serviceConfig.UMask = "0002";
  };
}
