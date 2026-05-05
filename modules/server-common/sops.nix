{
  lib,
  pkgs,
  config,
  ...
}:

let
  keyFile = "/var/lib/sops-nix/key.txt";
  sopsPrivateKey = "${config.variables.secretsDirectory}/sops-private-key";

  sopsKeyFileGenScript = pkgs.writeShellScript "sops-key-file-gen" ''
    if [ -s "${sopsPrivateKey}" ]; then
      install -Dm400 "${sopsPrivateKey}" "${keyFile}"
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
      before ? [ ],
      requiredBy ? [ ],
      wantedBy ? null,
      stripFinalNewline ? true,
    }:
    let
      effectiveWantedBy =
        if wantedBy == null then lib.optionals (requiredBy == [ ]) [ "multi-user.target" ] else wantedBy;
      copyScript = pkgs.writeShellScript "copy-secret-${name}" ''
        set -euo pipefail
        echo "[${name}] Copying ${source} to ${dest}"

        dest_dir=$(dirname "${dest}")
        if [ ! -d "$dest_dir" ]; then
          echo "[${name}] Creating directory $dest_dir"
          mkdir -p "$dest_dir"
        fi

        tmp_file=$(mktemp "$dest_dir/.${name}.XXXXXX")
        cleanup() {
          rm -f "$tmp_file"
        }
        trap cleanup EXIT

        ${
          if stripFinalNewline then
            ''${lib.getExe pkgs.perl} -pe 'chomp if eof' "${source}" > "$tmp_file"''
          else
            ''${pkgs.coreutils}/bin/cat "${source}" > "$tmp_file"''
        }
        chown "${user}":"${group}" "$tmp_file"
        chmod "${mode}" "$tmp_file"
        mv -f "$tmp_file" "${dest}"
        trap - EXIT

        echo "[${name}] Credentials installed with ${user}:${group} ownership and ${mode} perms"
      '';
    in
    {
      "copy-secret-${name}" = {
        description = "Copies decrypted ${name} secret to ${dest}";
        inherit before requiredBy;
        wantedBy = effectiveWantedBy;
        serviceConfig = {
          ExecStart = copyScript;
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
        ExecStart = sopsKeyFileGenScript;
        Type = "oneshot";
      };
    };
  };
}
