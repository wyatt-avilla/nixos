{ lib, ... }:
{
  options.variables = {
    filebrowser.port = lib.mkOption {
      type = lib.types.port;
      default = 8789;
    };

    microbin.port = lib.mkOption {
      type = lib.types.port;
      default = 2233;
    };

    immich.port = lib.mkOption {
      type = lib.types.port;
      default = 2283;
    };

    audiobookshelf.port = lib.mkOption {
      type = lib.types.port;
      default = 9981;
    };
  };
}
