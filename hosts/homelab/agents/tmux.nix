{ pkgs, ... }:
let
  tmuxBin = "${pkgs.tmux}/bin/tmux";
  resurrectSave = "${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/scripts/save.sh";
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

  users.users.wyatt.linger = true;

  systemd.user.services.wyatt-tmux = {
    description = "Persistent tmux session for wyatt";
    wantedBy = [ "default.target" ];
    unitConfig = {
      ConditionUser = "wyatt";
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
        "HOME=/home/wyatt"
        "SHELL=${pkgs.zsh}/bin/zsh"
        "TMUX_TMPDIR=%t"
      ];
      ExecStart = "${tmuxBin} -f /etc/tmux.conf new-session -d -s main";
      ExecStop = [
        "-${resurrectSave} quiet"
        "-${tmuxBin} kill-server"
      ];
      KillMode = "none";
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
