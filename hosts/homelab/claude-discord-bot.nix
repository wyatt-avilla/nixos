{ config, inputs, ... }:
{
  imports = [ inputs.claude-discord-bot.nixosModules.claude-discord-bot ];

  sops.secrets.claude-discord-bot-token = {
    owner = config.systemd.services.claude-discord-bot.serviceConfig.User;
    group = config.systemd.services.claude-discord-bot.serviceConfig.Group;
    path = "/var/lib/claude-discord-bot/discord-token.secret";
    mode = "0400";
  };

  services.claude-discord-bot = {
    enable = true;
    discordTokenFile = config.sops.secrets.claude-discord-bot-token.path;
  };
}
