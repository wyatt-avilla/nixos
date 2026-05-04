{
  config,
  lib,
  pkgs,
  ...
}:

let
  deployHome = "/var/lib/deploy";
  deployUser = "deploy";
  publicKeyFile = "${config.variables.secretsDirectory}/vps-deploy-public-key";

  activateScript = pkgs.writeShellApplication {
    name = "deploy-vps-activate";
    runtimeInputs = with pkgs; [
      coreutils
      nix
      systemd
    ];
    text = ''
      set -euo pipefail

      if [ "$#" -ne 1 ]; then
        echo "usage: deploy-vps-activate /nix/store/...-nixos-system-ambriel-..." >&2
        exit 64
      fi

      system_path="$1"

      case "$system_path" in
        /nix/store/*-nixos-system-${config.networking.hostName}-*) ;;
        *)
          echo "refusing to activate unexpected system path: $system_path" >&2
          exit 65
          ;;
      esac

      if [ ! -x "$system_path/bin/switch-to-configuration" ]; then
        echo "not a NixOS system closure: $system_path" >&2
        exit 66
      fi

      if [ ! -f "$system_path/nixos-version" ]; then
        echo "missing nixos-version in system closure: $system_path" >&2
        exit 67
      fi

      nix-env -p /nix/var/nix/profiles/system --set "$system_path"

      systemd-run \
        -E LOCALE_ARCHIVE \
        -E NIXOS_INSTALL_BOOTLOADER=0 \
        -E NIXOS_NO_CHECK \
        --collect \
        --no-ask-password \
        --pipe \
        --quiet \
        --service-type=exec \
        --unit=nixos-rebuild-switch-to-configuration \
        "$system_path/bin/switch-to-configuration" switch
    '';
  };

  authorizedKeysScript = pkgs.writeShellApplication {
    name = "deploy-vps-authorized-keys";
    runtimeInputs = with pkgs; [
      coreutils
      perl
    ];
    text = ''
      set -euo pipefail

      target="${deployHome}/.ssh/authorized_keys"

      if [ ! -f "${publicKeyFile}" ]; then
        echo "deploy public key ${publicKeyFile} not found" >&2
        exit 0
      fi

      install -d -m 700 -o ${deployUser} -g ${deployUser} "$(dirname "$target")"
      ${lib.getExe pkgs.perl} -pe 'chomp if eof' "${publicKeyFile}" > "$target"
      chown ${deployUser}:${deployUser} "$target"
      chmod 600 "$target"
    '';
  };
in
{
  users.users.${deployUser} = {
    isSystemUser = true;
    group = deployUser;
    home = deployHome;
    createHome = true;
    shell = pkgs.bash;
  };

  users.groups.${deployUser} = { };

  nix.settings.trusted-users = [ deployUser ];

  environment.systemPackages = [ activateScript ];

  systemd.services.deploy-vps-authorized-keys = {
    description = "Installs the VPS deploy user's authorized key";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = lib.getExe authorizedKeysScript;
      Type = "oneshot";
    };
  };

  services.openssh.extraConfig = ''
    Match User ${deployUser}
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      X11Forwarding no
      AllowAgentForwarding no
      PermitTTY no
  '';

  security.sudo.extraRules = [
    {
      users = [ deployUser ];
      commands = [
        {
          command = "/run/current-system/sw/bin/deploy-vps-activate";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
