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

  mkSecretsCopyService =
    {
      name,
      source,
      dest,
      user ? "root",
      group ? "root",
      mode ? "400",
      wantedBy ? [ "multi-user.target" ],
      before ? [ ],
    }:
    let
      copyScript = pkgs.writeShellScriptBin "copy-secret-${name}" ''
        set -euo pipefail
        echo "[${name}] Copying ${source} to ${dest}"

        dest_dir=$(dirname "${dest}")
        if [ ! -d "$dest_dir" ]; then
          echo "[${name}] Creating directory $dest_dir"
          mkdir -p "$dest_dir"
        fi

        ${lib.getExe pkgs.perl} -pe 'chomp if eof' "${source}" > "${dest}"
        chown "${user}":"${group}" "${dest}"

        echo "[${name}] Credentials installed with ${user}:${group} ownership and ${mode} perms"
      '';
    in
    {
      "copy-secret-${name}" = {
        description = "Copies decrypted ${name} secret to ${dest}";
        inherit wantedBy before;
        serviceConfig = {
          ExecStart = lib.getExe copyScript;
          Type = "oneshot";
        };
      };
    };
in
{
  options.variables.secretsDirectory = lib.mkOption {
    type = lib.types.str;
    default = "/run/secrets";
    description = "Decrypted SOPS secrets directory";
  };

  options.secrets.mkCopyService = lib.mkOption {
    type = lib.types.unspecified;
    default = mkSecretsCopyService;
    description = "Helper function to create a systemd oneshot service that copies a secret file to a destination with specified ownership and permissions";
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
