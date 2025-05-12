{ pkgs, config, ... }:
let
  port = 8789;
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
      ExecStart = "${pkgs.filebrowser}/bin/filebrowser --address 0.0.0.0 --port ${builtins.toString port} --root ${config.storageDir}";
      Restart = "always";
      User = "filebrowser";
    };
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
