{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  sshUser = config.variables.ssh.user;
  sshUserHome = config.users.users.${sshUser}.home;
  sshPrivateKeyFile = config.variables.ssh.privateKeyFile;
  sshPublicKeyFile = config.variables.ssh.publicKeyFile;

  plainTextKeys = [ inputs.nix-secrets.nixosModules.plainSecrets.phone.ssh.publicKey ];
  pathBasedKeys = [
    "${config.variables.secretsDirectory}/desktop-ssh-key"
    "${config.variables.secretsDirectory}/laptop-ssh-key"
    "${config.variables.secretsDirectory}/vps-ssh-key"
  ];

  shellArray =
    values: lib.concatMapStringsSep "\n" (value: "      ${lib.escapeShellArg value}") values;

  authorizedKeysGenScript = pkgs.writeShellScript "auth-key-file-gen" ''
        set -euo pipefail

        targetAuthorizedKeys="${sshUserHome}/.ssh/authorized_keys"

        mkdir -p "$(dirname "$targetAuthorizedKeys")"
        touch "$targetAuthorizedKeys"

        add_key() {
          key="$1"
          source="$2"

          if [ -z "$key" ]; then
            echo "Warning: Empty key from $source"
            return
          fi

          if ! grep -qF "$key" "$targetAuthorizedKeys"; then
            echo "$key" >> "$targetAuthorizedKeys"
            echo "Added key from $source to authorized_keys"
          else
            echo "Key from $source already present in authorized_keys"
          fi
        }

        plainTextKeys=(
    ${shellArray plainTextKeys}
        )

        pathBasedKeys=(
    ${shellArray pathBasedKeys}
        )

        for key in "''${plainTextKeys[@]}"; do
          add_key "$key" "plaintext key"
        done

        for keyFile in "''${pathBasedKeys[@]}"; do
          if [ -f "$keyFile" ]; then
            add_key "$(cat "$keyFile")" "$keyFile"
          else
            echo "Warning: Key file $keyFile not found"
          fi
        done

        chmod 600 "$targetAuthorizedKeys"
        chown ${sshUser}:users "$targetAuthorizedKeys"
  '';
in
{
  options.variables.ssh = {
    user = lib.mkOption {
      type = lib.types.str;
      default = "wyatt";
    };

    privateKeyFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/ssh/${config.networking.hostName}_ed25519";
    };

    publicKeyFile = lib.mkOption {
      type = lib.types.path;
      default = "${config.variables.ssh.privateKeyFile}.pub";
    };

    privateKeyCopyService = lib.mkOption {
      type = lib.types.str;
      default = "copy-secret-ssh-copy-private-key.service";
    };
  };

  config = {
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };

    systemd.services =
      (config.secrets.mkCopyService {
        name = "ssh-copy-private-key";
        source = "${config.variables.secretsDirectory}/ssh-private-key";
        dest = sshPrivateKeyFile;
        mode = "400";
        stripFinalNewline = false;
      })
      // (config.secrets.mkCopyService {
        name = "ssh-copy-public-key";
        source = "${config.variables.secretsDirectory}/ssh-public-key";
        dest = sshPublicKeyFile;
        mode = "444";
        stripFinalNewline = false;
      })
      // {
        auth-key-file-gen = {
          description = "Adds specified keys to the server's authorized SSH keys";
          wantedBy = [ "default.target" ];

          serviceConfig = {
            ExecStart = authorizedKeysGenScript;
            Type = "oneshot";
          };
        };
      };
  };
}
