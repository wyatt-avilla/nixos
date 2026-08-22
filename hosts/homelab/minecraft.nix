{
  config,
  inputs,
  pkgs,
  ...
}:
let
  inherit (inputs.nix-secrets.nixosModules.plainSecrets.homelab.minecraft) whitelist;
in
{
  services.minecraft-server = {
    enable = true;
    declarative = true;
    eula = true;
    dataDir = config.storage.paths.data.minecraft;
    package = pkgs.minecraft-server;
    jvmOpts = "-Xms1G -Xmx4G";

    serverProperties = {
      server-ip = config.variables.homelab.wireguard.ip;
      server-port = config.variables.minecraft.port;
      online-mode = true;
      white-list = true;
      enforce-whitelist = true;
      gamemode = "survival";
      difficulty = "normal";
      max-players = builtins.length whitelist;
      view-distance = 10;
      simulation-distance = 10;
      enable-rcon = false;
      enable-query = false;
      motd = "§d§lwemworld";
    };

    inherit whitelist;
  };

  users.users.minecraft.extraGroups = [ "storage" ];

  systemd.services.minecraft-server = {
    after = [ "ensure-storage-subvolumes.service" ];
    requires = [ "ensure-storage-subvolumes.service" ];
  };
}
