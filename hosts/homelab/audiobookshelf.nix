{ config, ... }:
{
  services.audiobookshelf = {
    enable = true;
    host = config.variables.homelab.wireguard.ip;
    inherit (config.variables.audiobookshelf) port;

    openFirewall = true;
  };

  systemd.services.audiobookshelf-setup = {
    description = "Ensure audiobookshelf directory exists";
    wantedBy = [ "audiobookshelf.service" ];
    before = [ "audiobookshelf.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.systemd.package}/bin/systemd-tmpfiles --create";
    };
  };
}
