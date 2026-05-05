{
  config,
  lib,
  pkgs,
  ...
}:

let
  deployHome = "/var/lib/deploy";
  repoPath = "${deployHome}/nixos-config";
  deployStatusDir = "${deployHome}/status";
  repoUrl = "git@github.com:wyatt-avilla/nixos.git";
  deployUser = "deploy";

  gitSshKey = config.variables.ssh.privateKeyFile;
  copyGitSshKeyService = config.variables.ssh.privateKeyCopyService;
  triggerPublicKey = "${config.variables.secretsDirectory}/homelab-deploy-trigger-public-key";
  vpsDeployKey = "${config.variables.secretsDirectory}/vps-deploy-private-key";
  vpsHost = "deploy@${config.variables.vps.wireguard.ip}";

  statusTool = pkgs.writers.writePython3Bin "nixos-deploy-status" { } ''
    import argparse
    import json
    import os
    import re
    import tempfile
    from datetime import datetime, timezone


    STATUS_DIR = ${builtins.toJSON deployStatusDir}
    HOSTS = ("vps", "homelab")
    VALID_STATES = {"queued", "in_progress", "success", "failure", "error"}
    TERMINAL_STATES = {"success", "failure", "error"}


    def now():
        return (
            datetime.now(timezone.utc)
            .replace(microsecond=0)
            .isoformat()
            .replace("+00:00", "Z")
        )


    def validate_run_id(run_id):
        if not re.fullmatch(r"[0-9]+", run_id):
            raise SystemExit(f"invalid run_id: {run_id}")


    def validate_sha(sha):
        if not re.fullmatch(r"[0-9a-f]{40}", sha):
            raise SystemExit(f"invalid sha: {sha}")


    def status_path(run_id):
        validate_run_id(run_id)
        return os.path.join(STATUS_DIR, f"{run_id}.json")


    def empty_status(run_id, sha):
        timestamp = now()
        return {
            "run_id": run_id,
            "sha": sha,
            "updated_at": timestamp,
            "hosts": {
                host: {
                    "state": "queued",
                    "description": f"{host} deploy queued.",
                    "updated_at": timestamp,
                }
                for host in HOSTS
            },
        }


    def load_status(run_id, sha=None, create=False):
        path = status_path(run_id)
        if not os.path.exists(path):
            if not create:
                raise SystemExit(f"status for run_id {run_id} does not exist")
            if sha is None:
                raise SystemExit("sha is required to create deployment status")
            validate_sha(sha)
            return empty_status(run_id, sha)

        with open(path, encoding="utf-8") as status_file:
            status = json.load(status_file)

        if str(status.get("run_id")) != run_id:
            raise SystemExit(f"status file run_id mismatch for {run_id}")
        if sha is not None and status.get("sha") != sha:
            raise SystemExit(f"status file sha mismatch for {run_id}")
        if "hosts" not in status or not isinstance(status["hosts"], dict):
            raise SystemExit(f"status file for {run_id} is missing hosts")

        return status


    def write_status(status):
        os.makedirs(STATUS_DIR, mode=0o755, exist_ok=True)
        fd, temp_path = tempfile.mkstemp(
            prefix=".status-",
            suffix=".json",
            dir=STATUS_DIR,
        )
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as status_file:
                json.dump(status, status_file, sort_keys=True)
                status_file.write("\n")
                status_file.flush()
                os.fsync(status_file.fileno())
            os.chmod(temp_path, 0o644)
            os.replace(temp_path, status_path(str(status["run_id"])))
        finally:
            try:
                os.unlink(temp_path)
            except FileNotFoundError:
                pass


    def init_status(run_id, sha):
        validate_run_id(run_id)
        validate_sha(sha)
        status = empty_status(run_id, sha)
        write_status(status)
        print(json.dumps(status, sort_keys=True))


    def set_host(run_id, sha, host, state, description):
        if host not in HOSTS:
            raise SystemExit(f"invalid host: {host}")
        if state not in VALID_STATES:
            raise SystemExit(f"invalid state: {state}")

        status = load_status(run_id, sha, create=True)
        timestamp = now()
        status["updated_at"] = timestamp
        status["hosts"][host] = {
            "state": state,
            "description": description,
            "updated_at": timestamp,
        }
        write_status(status)
        print(json.dumps(status, sort_keys=True))


    def fail_pending(run_id, sha, state, description):
        if state not in TERMINAL_STATES:
            raise SystemExit(f"invalid terminal state: {state}")

        status = load_status(run_id, sha, create=True)
        timestamp = now()
        status["updated_at"] = timestamp
        for host in HOSTS:
            host_status = status["hosts"].setdefault(host, {})
            if host_status.get("state") not in TERMINAL_STATES:
                status["hosts"][host] = {
                    "state": state,
                    "description": description,
                    "updated_at": timestamp,
                }
        write_status(status)
        print(json.dumps(status, sort_keys=True))


    def get_status(run_id):
        status = load_status(run_id)
        print(json.dumps(status, sort_keys=True))


    parser = argparse.ArgumentParser()
    subcommands = parser.add_subparsers(dest="command", required=True)

    init_parser = subcommands.add_parser("init")
    init_parser.add_argument("run_id")
    init_parser.add_argument("sha")

    set_parser = subcommands.add_parser("set")
    set_parser.add_argument("run_id")
    set_parser.add_argument("sha")
    set_parser.add_argument("host")
    set_parser.add_argument("state")
    set_parser.add_argument("description", nargs=argparse.REMAINDER)

    fail_pending_parser = subcommands.add_parser("fail-pending")
    fail_pending_parser.add_argument("run_id")
    fail_pending_parser.add_argument("sha")
    fail_pending_parser.add_argument("state")
    fail_pending_parser.add_argument("description", nargs=argparse.REMAINDER)

    get_parser = subcommands.add_parser("get")
    get_parser.add_argument("run_id")

    args = parser.parse_args()

    if args.command == "init":
        init_status(args.run_id, args.sha)
    elif args.command == "set":
        set_host(
            args.run_id,
            args.sha,
            args.host,
            args.state,
            " ".join(args.description).strip(),
        )
    elif args.command == "fail-pending":
        fail_pending(
            args.run_id,
            args.sha,
            args.state,
            " ".join(args.description).strip(),
        )
    elif args.command == "get":
        get_status(args.run_id)
    else:
        raise SystemExit(f"unknown command: {args.command}")
  '';

  deployScript = pkgs.writeShellApplication {
    name = "nixos-auto-deploy";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      flock
      git
      nix
      openssh
      systemd
    ];
    text = ''
      set -Eeuo pipefail

      if [ "$#" -ne 1 ]; then
        echo "usage: nixos-auto-deploy <run-id>-<sha>" >&2
        exit 64
      fi

      instance="$1"
      if [[ "$instance" =~ ^([0-9]+)-([0-9a-f]{40})$ ]]; then
        run_id="''${BASH_REMATCH[1]}"
        sha="''${BASH_REMATCH[2]}"
      else
        echo "invalid deploy instance: $instance" >&2
        exit 65
      fi

      current_host=""
      current_step="initializing deployment"

      set_status() {
        ${lib.getExe statusTool} set "$run_id" "$sha" "$1" "$2" "$3" >/dev/null
      }

      fail_pending() {
        ${lib.getExe statusTool} fail-pending "$run_id" "$sha" "$1" "$2" >/dev/null
      }

      on_error() {
        exit_code="$?"
        set +e

        case "$current_host" in
          vps)
            set_status vps failure "VPS deploy failed during $current_step."
            set_status homelab error "Homelab deploy was not attempted because VPS failed."
            ;;
          homelab)
            set_status homelab failure "Homelab deploy failed during $current_step."
            ;;
          *)
            fail_pending failure "Deployment failed during $current_step."
            ;;
        esac

        exit "$exit_code"
      }

      trap on_error ERR

      exec 9>/run/lock/nixos-auto-deploy.lock
      if ! flock -n 9; then
        set_status vps failure "Another deployment is already running."
        set_status homelab error "Homelab deploy was not attempted because another deployment is already running."
        exit 75
      fi

      export HOME=${deployHome}
      export GIT_SSH_COMMAND="${lib.getExe pkgs.openssh} -i ${gitSshKey} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

      current_step="preparing checkout"
      install -d -m 755 ${deployHome}
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

      current_step="building host closures"
      set_status vps in_progress "Building VPS and homelab closures."
      set_status homelab queued "Waiting for VPS deploy to finish."

      echo "building vps and homelab closures for $sha"
      vps_path="$(nix build --print-out-paths --no-link .#nixosConfigurations.vps.config.system.build.toplevel)"
      homelab_path="$(nix build --print-out-paths --no-link .#nixosConfigurations.homelab.config.system.build.toplevel)"

      export NIX_SSHOPTS="-i ${vpsDeployKey} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

      current_host="vps"
      current_step="copying VPS closure"
      set_status vps in_progress "Copying VPS closure."
      echo "copying vps closure to ${vpsHost}"
      nix copy --to ssh://${vpsHost} "$vps_path"

      current_step="activating VPS"
      set_status vps in_progress "Activating VPS."
      echo "activating vps"
      ssh \
        -i ${vpsDeployKey} \
        -o IdentitiesOnly=yes \
        -o StrictHostKeyChecking=accept-new \
        ${vpsHost} \
        -- sudo /run/current-system/sw/bin/deploy-vps-activate "$vps_path"
      set_status vps success "VPS activated."

      current_host="homelab"
      current_step="activating homelab"
      set_status homelab in_progress "Activating homelab."
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
      set_status homelab success "Homelab activated."

      trap - ERR
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

      if [ "$#" -ne 3 ] || [ "$1" != "start" ]; then
        echo "usage: homelab-deploy-trigger-root start <run-id> <sha>" >&2
        exit 64
      fi

      run_id="$2"
      sha="$3"

      if [[ ! "$run_id" =~ ^[0-9]+$ ]]; then
        echo "invalid run id: $run_id" >&2
        exit 65
      fi

      if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
        echo "invalid sha: $sha" >&2
        exit 65
      fi

      install -d -m 755 ${deployHome}
      ${lib.getExe statusTool} init "$run_id" "$sha" >/dev/null
      systemctl start --no-block "nixos-auto-deploy@$run_id-$sha.service"
    '';
  };

  forcedCommandScript = pkgs.writeShellApplication {
    name = "homelab-deploy-ssh";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
      set -euo pipefail

      original_command="''${SSH_ORIGINAL_COMMAND:-}"

      if [[ "$original_command" =~ ^deploy-start[[:space:]]([0-9]+)[[:space:]]([0-9a-f]{40})$ ]]; then
        exec /run/wrappers/bin/sudo ${lib.getExe rootTriggerScript} start "''${BASH_REMATCH[1]}" "''${BASH_REMATCH[2]}"
      fi

      if [[ "$original_command" =~ ^deploy-status[[:space:]]([0-9]+)$ ]]; then
        exec ${lib.getExe statusTool} get "''${BASH_REMATCH[1]}"
      fi

      if [[ "$original_command" =~ ^deploy-all[[:space:]]([0-9a-f]{40})$ ]]; then
        run_id="$(date +%s)"
        exec /run/wrappers/bin/sudo ${lib.getExe rootTriggerScript} start "$run_id" "''${BASH_REMATCH[1]}"
      fi

      echo "usage: deploy-start <run-id> <sha> | deploy-status <run-id> | deploy-all <sha>" >&2
      exit 64
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

  systemd.services = {
    deploy-homelab-authorized-keys = {
      description = "Installs the homelab deploy trigger authorized key";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = lib.getExe authorizedKeysScript;
        Type = "oneshot";
      };
    };

    "nixos-auto-deploy@" = {
      description = "Builds and deploys NixOS hosts for GitHub run/commit %i";
      after = [
        "network-online.target"
        "wireguard-wg0.service"
        copyGitSshKeyService
      ];
      requires = [ copyGitSshKeyService ];
      wants = [ "network-online.target" ];
      path = with pkgs; [
        nix
        openssh
        systemd
      ];
      serviceConfig = {
        ExecStart = "${lib.getExe deployScript} %i";
        Type = "oneshot";
        StateDirectory = [
          "deploy/nixos-config"
          "deploy/status"
        ];
        WorkingDirectory = repoPath;
        TimeoutStartSec = "2h";
      };
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
