{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.services.homelabObservability;
  isHomelab = config.networking.hostName == "barachiel";
  homeIp = config.variables.homelab.wireguard.ip;
in
{
  imports = [
    inputs.attosend.nixosModules.attosend
    ./prometheus.nix
  ];
  options.services.homelabObservability = {
    enable = lib.mkEnableOption "host and application observability";
    peer = lib.mkOption {
      type = lib.types.str;
      default = if isHomelab then config.variables.vps.wireguard.ip else homeIp;
    };
    failureSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 120;
    };
  };
  config = lib.mkIf cfg.enable {
    services.attosend = {
      enable = true;
      sender = lib.mkDefault "alerts@${inputs.nix-secrets.nixosModules.plainSecrets.domain.personal}";
      recipient = lib.mkDefault inputs.nix-secrets.nixosModules.plainSecrets.email.personal;
      credentialPath = lib.mkDefault config.sops.secrets.resend-api-key.path;
      checks = {
        inherit (cfg) peer failureSeconds;
      };
    };
    sops.secrets.resend-api-key.restartUnits = [ "attosend.service" ];
    systemd.services.attosend.after = [ "sops-nix.service" ];
  };
}
