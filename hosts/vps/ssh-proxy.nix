{ config, ... }:
let
  homelabIp = config.variables.homelab.wireguard.ip;
  proxyPort = 2222;
  sshPort = 22;
in
{
  networking.firewall.allowedTCPPorts = [ proxyPort ];

  services.openssh = {
    ports = [
      sshPort
      proxyPort
    ];

    extraConfig = ''
      Match LocalPort ${toString proxyPort}
        AllowTcpForwarding local
        PermitOpen ${homelabIp}:${toString sshPort}
        X11Forwarding no
        AllowAgentForwarding no
        PermitTunnel no
        PermitTTY no
        ForceCommand echo "Use this port as an SSH jump host to ${homelabIp}:${toString sshPort}."
    '';
  };
}
