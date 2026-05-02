{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  sshUser = "wyatt";
  sshUserHome = config.users.users.${sshUser}.home;

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
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  systemd.services.auth-key-file-gen = {
    description = "Adds specified keys to the server's authorized SSH keys";
    wantedBy = [ "default.target" ];

    serviceConfig = {
      ExecStart = authorizedKeysGenScript;
      Type = "oneshot";
    };
  };
}
