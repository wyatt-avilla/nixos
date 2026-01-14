{ config, inputs, ... }:
let
  privateKeyFile = "/etc/wireguard/private.key";
in
{
  networking.firewall = {
    allowedUDPPorts = [ config.variables.vps.wireguard.port ];
  };

  networking.wireguard.interfaces = {
    wg0 = {
      ips = [ "${config.variables.vps.wireguard.ip}/24" ];

      listenPort = config.variables.vps.wireguard.port;

      inherit privateKeyFile;

      peers = [
        {
          inherit (inputs.nix-secrets.nixosModules.plainSecrets.homelab.wireguard) publicKey;
          allowedIPs = [ "${config.variables.homelab.wireguard.ip}/32" ];
        }
      ];
    };
  };

  systemd.services = config.secrets.mkCopyService {
    name = "vps-copy-wireguard-private-key";
    source = "${config.variables.secretsDirectory}/wireguard-private-key";
    dest = privateKeyFile;
    mode = "600";
  };
}
