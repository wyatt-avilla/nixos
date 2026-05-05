{ config, inputs, ... }:
let
  tokenFile = "/var/lib/claude-discord-bot/discord-token";
  botService = config.systemd.services.claude-discord-bot;
  botGroup = botService.serviceConfig.Group;
  botUser = botService.serviceConfig.User;
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
    consumerService = botService;
  };
}
