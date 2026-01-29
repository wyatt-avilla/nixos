{ config, ... }:
{
  services.audiobookshelf = {
    enable = true;
    port = 9981;
    dataDir = "${config.storageDir}/audiobookshelf";

    openFirewall = true; # TODO: change
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
