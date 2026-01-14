{ inputs, config, ... }:
let
  privateKeyFile = "/etc/wireguard/private.key";

  wgInterface = "wg0";
in
{
  networking = {
    firewall.trustedInterfaces = [ wgInterface ];

    wireguard.interfaces = {
      ${wgInterface} = {
        ips = [ "${config.variables.homelab.wireguard.ip}/24" ];

        inherit privateKeyFile;

        peers = [
          {
            inherit (inputs.nix-secrets.nixosModules.plainSecrets.vps.wireguard) publicKey;

            endpoint = "${config.variables.vps.publicIp}:${toString config.variables.vps.wireguard.port}";

            allowedIPs = [ "10.0.0.0/24" ];

            persistentKeepalive = 25;
          }
        ];
      };
    };
  };

  systemd.services = config.secrets.mkCopyService {
    name = "homelab-copy-wireguard-private-key";
    source = "${config.variables.secretsDirectory}/wireguard-private-key";
    dest = privateKeyFile;
    mode = "600";
  };
}
