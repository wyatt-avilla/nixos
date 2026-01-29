{ config, ... }:
{
  services.audiobookshelf = {
    enable = true;
    host = "0.0.0.0"; # TODO: change
    port = 9981;

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
