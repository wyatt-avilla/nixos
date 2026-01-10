{ config, inputs, ... }:
let
  tokenFile = "/var/lib/claude-discord-bot/discord-token";
  botGroup = config.systemd.services.claude-discord-bot.serviceConfig.Group;
  botUser = config.systemd.services.claude-discord-bot.serviceConfig.User;
in
{
  imports = [ inputs.claude-discord-bot.nixosModules.claude-discord-bot ];

  services.claude-discord-bot = {
    enable = true;
    discordTokenFile = tokenFile;
  };

  systemd.services = config.secrets.mkCopyService {
    name = "claude-discord-bot-token";
    source = "${config.variables.secretsDirectory}/claude-discord-bot-token";
    dest = tokenFile;
    user = botUser;
    group = botGroup;
    before = [ "claude-discord-bot.service" ];
    wantedBy = [ "claude-discord-bot.service" ];
  };
}
