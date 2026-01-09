{ lib, config, ... }:
{
  options.variables.secretsDirectory = lib.mkOption {
    type = lib.types.str;
    default = "/run/secrets";
    description = "Decrypted SOPS secrets directory";
  };

  config = {
    sops.age.keyFile = "${config.variables.secretsDirectory}/sops-private-key";
  };
}
