{
  lib,
  pkgs,
  config,
  ...
}:
let
  desktopKey = "${config.variables.secretsDirectory}/desktop-ssh-key";

  authorizedKeysGenScript = pkgs.writeShellScriptBin "auth-key-file-gen" ''
    set -euo pipefail

    keyFile="${desktopKey}"
    targetAuthorizedKeys="/root/.ssh/authorized_keys"

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
    chown root:root "$targetAuthorizedKeys"
  '';
in
{
  services.openssh = {
    enable = true;
  };

  systemd.services.auth-key-file-gen = {
    description = "Copies SOPS private key to the age key file location, if present.";
    wantedBy = [ "default.target" ];

    serviceConfig = {
      ExecStart = "${authorizedKeysGenScript}/bin/auth-key-file-gen";
      Type = "oneshot";
    };
  };
}
