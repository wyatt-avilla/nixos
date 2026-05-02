{ lib, pkgs, ... }:
let
  tmuxBin = "${lib.getExe pkgs.tmux}";
  tmuxEnsureSession = pkgs.writeShellApplication {
    name = "tmux-ensure-session";
    runtimeInputs = with pkgs; [
      tmux
    ];
    text = ''
      set -euo pipefail

      session="main"
      tmux_args=(-f /etc/tmux.conf)

      if tmux "''${tmux_args[@]}" has-session -t "$session" 2>/dev/null; then
        exit 0
      fi

      set +e
      output=$(tmux "''${tmux_args[@]}" new-session -d -s "$session" 2>&1)
      status=$?
      set -e

      if [[ "$status" -eq 0 ]]; then
        exit 0
      fi

      if tmux "''${tmux_args[@]}" has-session -t "$session" 2>/dev/null; then
        exit 0
      fi

      printf '%s\n' "$output" >&2
      exit "$status"
    '';
  };
  tmuxGitStatus = pkgs.writeShellApplication {
    name = "tmux-git-status";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      git
    ];
    text = ''
      set -euo pipefail

      cwd="''${1:-$PWD}"
      if ! repo_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null); then
        exit 0
      fi

      repo=$(basename "$repo_root")
      branch=$(
        git -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null \
          || git -C "$cwd" rev-parse --short HEAD 2>/dev/null \
          || true
      )

      if [[ -z "$branch" ]]; then
        exit 0
      fi

      read -r added deleted < <(
        {
          git -C "$cwd" diff --numstat
          git -C "$cwd" diff --cached --numstat
        } | awk '
          BEGIN { added = 0; deleted = 0 }
          $1 ~ /^[0-9]+$/ { added += $1 }
          $2 ~ /^[0-9]+$/ { deleted += $2 }
          END { printf "%d %d\n", added, deleted }
        '
      )

      printf "%s/%s +%s|-%s\n" "$repo" "$branch" "$added" "$deleted"
    '';
  };
  resurrectSave = "${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/scripts/save.sh";
  targetUser = "wyatt";
in
{
  programs.tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [
      resurrect
      continuum
    ];
    extraConfigBeforePlugins = ''
      set -g @continuum-restore 'on'
      set -g @continuum-save-interval '15'
    '';
    extraConfig = ''
      set -g status-interval 5
      set -g status-right "#(${lib.getExe tmuxGitStatus} #{q:pane_current_path})"
    '';
  };

  users.users.${targetUser}.linger = true;

  systemd.user.services.wyatt-tmux = {
    description = "Persistent tmux session for ${targetUser}";
    wantedBy = [ "default.target" ];
    unitConfig = {
      ConditionUser = targetUser;
      Documentation = "man:tmux(1)";
    };

    path = with pkgs; [
      bash
      coreutils
      gawk
      gnugrep
      gnused
      procps
      pkgs.tmux
      util-linux
    ];

    restartIfChanged = false;

    serviceConfig = {
      Type = "forking";
      Environment = [
        "HOME=/home/${targetUser}"
        "SHELL=${lib.getExe pkgs.zsh}"
        "TMUX_TMPDIR=%t"
      ];
      ExecStart = lib.getExe tmuxEnsureSession;
      ExecStop = [
        "-${resurrectSave} quiet"
        "-${tmuxBin} kill-server"
      ];
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
