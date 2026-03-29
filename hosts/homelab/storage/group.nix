{
  users.groups.storage = { };

  services = {
    syncthing.group = "storage";
    immich.group = "storage";
    filebrowser.group = "storage";
    audiobookshelf.group = "storage";
  };

  users.users = {
    microbin.extraGroups = [ "storage" ];
  };
}
