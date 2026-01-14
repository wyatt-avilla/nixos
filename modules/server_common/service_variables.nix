{ lib, ... }:
{
  options.variables.filebrowser.port = lib.mkOption {
    type = lib.types.port;
    default = 8789;
  };
}
