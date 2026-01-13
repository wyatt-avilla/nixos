{ config, inputs, ... }:
let
  privateKeyFile = "/etc/wireguard/private.key";
in
{
  networking.firewall = {
    allowedUDPPorts = [ 51820 ];
  };

  networking.wireguard.interfaces = {
    wg0 = {
      ips = [ "10.0.0.1/24" ];

      listenPort = 51820;

      inherit privateKeyFile;

      peers = [
        {
          inherit (inputs.nix-secrets.nixosModules.plainSecrets.homelab.wireguard) publicKey;
          allowedIPs = [ "10.0.0.2/32" ];
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
