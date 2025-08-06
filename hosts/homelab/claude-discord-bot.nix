{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  claude-discord-bot-token = "${config.variables.secretsDirectory}/claude-discord-bot-token";

  tokenFile = "/etc/claude-discord-bot/discord-token";
  botGroup = config.systemd.services.claude-discord-bot.serviceConfig.Group;
  botUser = config.systemd.services.claude-discord-bot.serviceConfig.User;

  copyToken = pkgs.writeShellScriptBin "copy-claude-discord-bot-token" ''
    set -euo pipefail

    echo "[Claude Discord bot setup] Copying credentials to ${tokenFile}"

    install -Dm400 "${claude-discord-bot-token}" "${tokenFile}"

    chown "${botUser}":"${botGroup}" "${tokenFile}"
    echo "[Claude Discord bot setup] Credentials installed with '''${botUser}:${botGroup}''' ownership and 400 perms"
  '';
in
{
  imports = [ inputs.claude-discord-bot.nixosModules.claude-discord-bot ];

  services.claude-discord-bot = {
    enable = true;
    discordTokenFile = tokenFile;
  };

  systemd.services.copy-discord-token = {
    description = "Copies decrypted Cluade Discord bot token into expected location";
    wantedBy = [ "claude-discord-bot.service" ];
    before = [ "claude-discord-bot.service" ];

    serviceConfig = {
      ExecStart = lib.getExe copyToken;
      Type = "oneshot";
    };
  };
}
