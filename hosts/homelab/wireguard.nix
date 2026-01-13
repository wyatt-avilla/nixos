{ inputs, config, ... }:
let
  privateKeyFile = "/etc/wireguard/private.key";
in
{
  networking.wireguard.interfaces = {
    wg0 = {
      ips = [ "10.0.0.2/24" ];

      inherit privateKeyFile;

      peers = [
        {
          inherit (inputs.nix-secrets.nixosModules.plainSecrets.vps.wireguard) publicKey;

          endpoint = "134.199.142.228:51820";

          allowedIPs = [ "10.0.0.0/24" ];

          persistentKeepalive = 25;
        }
      ];
    };
  };

  systemd.services = config.secrets.mkCopyService {
    name = "homelab-copy-wireguard-private-key";
    source = "${config.variables.secretsDirectory}/wireguard-private-key";
    dest = privateKeyFile;
    mode = "600";
  };
}
