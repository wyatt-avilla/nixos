{ lib, pkgs, ... }:
let
  tmuxBin = "${lib.getExe pkgs.tmux}";
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
      ExecStart = "${tmuxBin} -f /etc/tmux.conf new-session -d -s main";
      ExecStop = [
        "-${resurrectSave} quiet"
        "-${tmuxBin} kill-server"
      ];
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
