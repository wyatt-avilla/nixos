{ pkgs, config, ... }:
let
  port = 8789;
in
{
  systemd.services.filebrowser = {
    description = "Filebrowser Web UI";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.filebrowser}/bin/filebrowser --address 0.0.0.0 --port ${builtins.toString port} --root ${config.storageDir}";
      Restart = "always";
      User = "filebrowser";
      Group = "filebrowser";
    };
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
