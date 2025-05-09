{
  lib,
  pkgs,
  config,
  ...
}:
let
  sshUser = "wyatt";
  sshUserHome = config.users.users.${sshUser}.home;

  desktopKey = "${config.variables.secretsDirectory}/desktop-ssh-key";

  authorizedKeysGenScript = pkgs.writeShellScriptBin "auth-key-file-gen" ''
    set -euo pipefail

    keyFile="${desktopKey}"
    targetAuthorizedKeys="${sshUserHome}/.ssh/authorized_keys"

    mkdir -p "$(dirname "$targetAuthorizedKeys")"
    touch "$targetAuthorizedKeys"

    key="$(cat "$keyFile")"

    if ! grep -qF "$key" "$targetAuthorizedKeys"; then
      echo "$key" >> "$targetAuthorizedKeys"
      echo "Added key to authorized_keys"
    else
      echo "Key already present in authorized_keys"
    fi

    chmod 600 "$targetAuthorizedKeys"
    chown ${sshUser}:users "$targetAuthorizedKeys"
  '';
in
{
  services.openssh = {
    enable = true;
  };

  systemd.services.auth-key-file-gen = {
    description = "Adds specified keys to the server's authorized SSH keys";
    wantedBy = [ "default.target" ];

    serviceConfig = {
      ExecStart = "${authorizedKeysGenScript}/bin/auth-key-file-gen";
      Type = "oneshot";
    };
  };
}
