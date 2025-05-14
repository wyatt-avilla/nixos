{ pkgs, config, ... }:
let
  port = 8789;
  rootDir = "${config.storageDir}/filebrowser";
in
{
  users.users.filebrowser = {
    isSystemUser = true;
  };

  systemd.services.filebrowser = {
    description = "Filebrowser Web UI";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.filebrowser}/bin/filebrowser --port ${builtins.toString port} --root ${rootDir} --database ${rootDir}/filebrowser.db";
      Restart = "always";
      User = "filebrowser";
    };
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
