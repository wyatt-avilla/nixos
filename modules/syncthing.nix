let
  syncthingDir = "/var/lib/syncthing/";
in
{
  users.users.wyatt = {
    extraGroups = [ "syncthing" ];
  };

  services.syncthing = {
    enable = true;
    overrideFolders = false;
    dataDir = syncthingDir;
    settings = {
      devices = {
        "ubuntu-closet" = {
          id = "SNVTFBL-IBYKYJA-5A2ZSO6-4YDVZO5-HQUCMGS-Y7IAYFA-7A4F527-VWSLTQC";
        };
      };
    };
  };

  systemd = {
    services.syncthing.environment.STNODEFAULTFOLDER = "true";
    tmpfiles.rules = [ "d ${syncthingDir} 0770 syncthing syncthing" ];
  };
}
