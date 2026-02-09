{ pkgs, config, ... }:
let
  sshUser = "wyatt";
  sshUserHome = config.users.users.${sshUser}.home;

  desktopKey = "${config.variables.secretsDirectory}/desktop-ssh-key";
  laptopKey = "${config.variables.secretsDirectory}/laptop-ssh-key";
  vpsKey = "${config.variables.secretsDirectory}/vps-ssh-key";

  authorizedKeysGenScript = pkgs.writeShellScript "auth-key-file-gen" ''
    set -euo pipefail

    targetAuthorizedKeys="${sshUserHome}/.ssh/authorized_keys"

    mkdir -p "$(dirname "$targetAuthorizedKeys")"
    touch "$targetAuthorizedKeys"

    for keyFile in "${desktopKey}" "${laptopKey}" "${vpsKey}"; do
      if [ -f "$keyFile" ]; then
        key="$(cat "$keyFile")"

        if ! grep -qF "$key" "$targetAuthorizedKeys"; then
          echo "$key" >> "$targetAuthorizedKeys"
          echo "Added key from $keyFile to authorized_keys"
        else
          echo "Key from $keyFile already present in authorized_keys"
        fi
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
