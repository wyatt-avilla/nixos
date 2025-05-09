{
  lib,
  pkgs,
  config,
  ...
}:

let
  keyFile = "/var/lib/sops-nix/key.txt";
  sopsPrivateKey = "${config.variables.secretsDirectory}/sops-private-key";

  sopsKeyFileGenScript = pkgs.writeShellScriptBin "sops-key-file-gen" ''
    if [ -s "${sopsPrivateKey}" ]; then
      cp -f "${sopsPrivateKey}" "${keyFile}"
    fi
  '';
in
{
  options.variables.secretsDirectory = lib.mkOption {
    type = lib.types.str;
    default = "/run/secrets";
    description = "Decrypted SOPS secrets directory";
  };

  config = {
    sops.age.keyFile = keyFile;

    systemd.services.sops-key-file-gen = {
      description = "Copies SOPS private key to the age key file location, if present.";
      wantedBy = [ "default.target" ];

      serviceConfig = {
        ExecStart = "${sopsKeyFileGenScript}/bin/sops-key-file-gen";
        Type = "oneshot";
      };
    };
  };
}
