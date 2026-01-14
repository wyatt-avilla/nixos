{ lib, ... }:
{
  options.variables.filebrowser.port = lib.mkOption {
    type = lib.types.port;
    default = 8789;
  };

  options.variables.microbin.port = lib.mkOption {
    type = lib.types.port;
    default = 2233;
  };
}
