{
  pkgs,
  config,
  inputs,
  ...
}:
let
  syncthingDir = "${config.storageDir}/syncthing";
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
  };

  systemd.services.syncthing-perms-fixer =
    let
      syncthing-perms-fixer = pkgs.writeShellScriptBin "syncthing-perms-fixer" ''
        ${pkgs.lib.getExe' pkgs.inotify-tools "inotifywait"} -m -r -e create,moved_to ${syncthingDir} | \
        while read -r path action file; do
          fullpath="$path$file"
          if [ -f "$fullpath" ]; then
            ${pkgs.lib.getExe' pkgs.coreutils "chmod"} 664 "$fullpath"
          elif [ -d "$fullpath" ]; then
            ${pkgs.lib.getExe' pkgs.coreutils "chmod"} 775 "$fullpath"
          fi
        done
      '';
    in
    {
      description = "Fix permissions in Syncthing directory";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.lib.getExe syncthing-perms-fixer}";
        Restart = "always";
        RestartSec = "5s";
      };
    };
}
