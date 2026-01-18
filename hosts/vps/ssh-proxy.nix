{ config, ... }:
let
  homelabIp = config.variables.homelab.wireguard.ip;
  vpsWgIp = config.variables.vps.wireguard.ip;
  proxyPort = 2222;
  sshPort = 22;
in
{
  networking.firewall.allowedTCPPorts = [ proxyPort ];

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  networking.nat = {
    enable = true;
    internalInterfaces = [ "wg0" ];
    externalInterface = "ens3";
    forwardPorts = [
      {
        sourcePort = proxyPort;
        destination = "${homelabIp}:${toString sshPort}";
        proto = "tcp";
      }
    ];
    extraCommands = ''
      iptables -t nat -A nixos-nat-post -d ${homelabIp} -o wg0 -j SNAT --to-source ${vpsWgIp}
    '';
    extraStopCommands = ''
      iptables -t nat -D nixos-nat-post -d ${homelabIp} -o wg0 -j SNAT --to-source ${vpsWgIp} || true
    '';
  };
}
