{
  config,
  lib,
  pkgs,
  ...
}:

let
  deployHome = "/var/lib/deploy";
  repoPath = "${deployHome}/nixos-config";
  repoUrl = "git@github.com:wyatt-avilla/nixos.git";
  deployUser = "deploy";

  gitSshKey =
    (lib.findFirst (
      key: key.type == "ed25519"
    ) (throw "homelab deploy requires an ed25519 OpenSSH host key") config.services.openssh.hostKeys)
    .path;
  triggerPublicKey = "${config.variables.secretsDirectory}/homelab-deploy-trigger-public-key";
  vpsDeployKey = "${config.variables.secretsDirectory}/vps-deploy-private-key";
  vpsHost = "deploy@${config.variables.vps.wireguard.ip}";

  deployScript = pkgs.writeShellApplication {
    name = "nixos-auto-deploy";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      flock
      git
      nix
      openssh
    ];
    text = ''
      set -euo pipefail

      if [ "$#" -ne 1 ]; then
        echo "usage: nixos-auto-deploy <sha>" >&2
        exit 64
      fi

      sha="$1"

      case "$sha" in
        [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
        *)
          echo "invalid sha: $sha" >&2
          exit 65
          ;;
      esac

      exec 9>/run/lock/nixos-auto-deploy.lock
      if ! flock -n 9; then
        echo "another deploy is already running" >&2
        exit 75
      fi

      export HOME=${deployHome}
      export GIT_SSH_COMMAND="${lib.getExe pkgs.openssh} -i ${gitSshKey} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

      install -d -m 700 ${deployHome}
      install -d -m 755 ${repoPath}

      if [ ! -d ${repoPath}/.git ]; then
        git clone ${repoUrl} ${repoPath}
      fi

      cd ${repoPath}
      git remote set-url origin ${repoUrl}
      git fetch --prune origin
      git fetch origin "$sha"
      git checkout --detach "$sha"
      git clean -fdx

      echo "building vps and homelab closures for $sha"
      vps_path="$(nix build --print-out-paths --no-link .#nixosConfigurations.vps.config.system.build.toplevel)"
      homelab_path="$(nix build --print-out-paths --no-link .#nixosConfigurations.homelab.config.system.build.toplevel)"

      export NIX_SSHOPTS="-i ${vpsDeployKey} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

      echo "copying vps closure to ${vpsHost}"
      nix copy --to ssh://${vpsHost} "$vps_path"

      echo "activating vps"
      ssh \
        -i ${vpsDeployKey} \
        -o IdentitiesOnly=yes \
        -o StrictHostKeyChecking=accept-new \
        ${vpsHost} \
        -- sudo /run/current-system/sw/bin/deploy-vps-activate "$vps_path"

      echo "activating homelab"
      nix-env -p /nix/var/nix/profiles/system --set "$homelab_path"
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
        "$homelab_path/bin/switch-to-configuration" switch
    '';
  };

  rootTriggerScript = pkgs.writeShellApplication {
    name = "homelab-deploy-trigger-root";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
    ];
    text = ''
      set -euo pipefail

      if [ "$#" -ne 1 ]; then
        echo "usage: homelab-deploy-trigger-root <sha>" >&2
        exit 64
      fi

      sha="$1"

      case "$sha" in
        [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
        *)
          echo "invalid sha: $sha" >&2
          exit 65
          ;;
      esac

      systemctl start --no-block "nixos-auto-deploy@$sha.service"
    '';
  };

  forcedCommandScript = pkgs.writeShellApplication {
    name = "homelab-deploy-ssh";
    runtimeInputs = with pkgs; [
      coreutils
      sudo
    ];
    text = ''
      set -euo pipefail

      original_command="''${SSH_ORIGINAL_COMMAND:-}"

      if [[ ! "$original_command" =~ ^deploy-all[[:space:]]([0-9a-f]{40})$ ]]; then
        echo "usage: deploy-all <sha>" >&2
        exit 64
      fi

      exec sudo ${lib.getExe rootTriggerScript} "''${BASH_REMATCH[1]}"
    '';
  };

  authorizedKeysScript = pkgs.writeShellApplication {
    name = "deploy-homelab-authorized-keys";
    runtimeInputs = with pkgs; [
      coreutils
      perl
    ];
    text = ''
      set -euo pipefail

      target="${deployHome}/.ssh/authorized_keys"

      if [ ! -f "${triggerPublicKey}" ]; then
        echo "deploy trigger public key ${triggerPublicKey} not found" >&2
        exit 0
      fi

      install -d -m 700 -o ${deployUser} -g ${deployUser} "$(dirname "$target")"
      key="$(${lib.getExe pkgs.perl} -pe 'chomp if eof' "${triggerPublicKey}")"
      printf 'restrict,command="%s" %s\n' "${lib.getExe forcedCommandScript}" "$key" > "$target"
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

  systemd.services.deploy-homelab-authorized-keys = {
    description = "Installs the homelab deploy trigger authorized key";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = lib.getExe authorizedKeysScript;
      Type = "oneshot";
    };
  };

  systemd.services."nixos-auto-deploy@" = {
    description = "Builds and deploys NixOS hosts at commit %i";
    after = [
      "network-online.target"
      "wireguard-wg0.service"
    ];
    wants = [ "network-online.target" ];
    path = with pkgs; [
      nix
      openssh
    ];
    serviceConfig = {
      ExecStart = "${lib.getExe deployScript} %i";
      Type = "oneshot";
      StateDirectory = "deploy/nixos-config";
      WorkingDirectory = repoPath;
      TimeoutStartSec = "2h";
    };
  };

  security.sudo.extraRules = [
    {
      users = [ deployUser ];
      commands = [
        {
          command = lib.getExe rootTriggerScript;
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
