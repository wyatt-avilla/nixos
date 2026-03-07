{ pkgs, lib, ... }:
let
  metadataBase = "http://169.254.169.254/metadata/v1";

  configureNetworking = pkgs.writeShellScript "do-configure-networking" ''
    set -euo pipefail

    CURL="${lib.getExe pkgs.curl} -fsSL --retry 5 --retry-delay 1 --connect-timeout 5"
    IFACE="ens3"

    # Convert a dotted netmask to a CIDR prefix length
    netmask_to_prefix() {
      local mask="$1" prefix=0 octet
      IFS='.' read -r -a octets <<< "$mask"
      for octet in "''${octets[@]}"; do
        while [ "$octet" -gt 0 ]; do
          prefix=$(( prefix + (octet & 1) ))
          octet=$(( octet >> 1 ))
        done
      done
      echo "$prefix"
    }

    # Ensure the interface is up
    ip link set "$IFACE" up
    sleep 1

    # Add a temporary link-local address to reach the metadata API
    ip addr add 169.254.1.1/16 dev "$IFACE" 2>/dev/null || true

    # Wait for metadata API to become reachable
    for i in $(seq 1 10); do
      if $CURL -o /dev/null ${metadataBase}/ 2>/dev/null; then
        break
      fi
      echo "Waiting for metadata API (attempt $i/10)..."
      sleep 1
    done

    # Fetch networking configuration from DO metadata API
    IP=$($CURL ${metadataBase}/interfaces/public/0/ipv4/address)
    NETMASK=$($CURL ${metadataBase}/interfaces/public/0/ipv4/netmask)
    GATEWAY=$($CURL ${metadataBase}/interfaces/public/0/ipv4/gateway)

    PREFIX=$(netmask_to_prefix "$NETMASK")
    echo "Configuring $IFACE: $IP/$PREFIX gateway $GATEWAY"

    # Remove the temporary link-local address and any stale config
    ip addr flush dev "$IFACE"

    # Apply the real configuration
    ip addr add "$IP/$PREFIX" dev "$IFACE"
    ip route add default via "$GATEWAY" dev "$IFACE"

    echo "Networking configured successfully: $IP/$PREFIX via $GATEWAY"
  '';
in
{
  networking = {
    networkmanager.enable = lib.mkForce false;
    useDHCP = lib.mkForce false;
    dhcpcd.enable = lib.mkForce false;
  };

  # DigitalOcean DNS nameservers
  networking.nameservers = [
    "67.207.67.3"
    "67.207.67.2"
  ];

  systemd.services.do-configure-networking = {
    description = "Configure networking from DigitalOcean metadata API";
    wantedBy = [
      "network-online.target"
      "multi-user.target"
    ];
    before = [
      "network-online.target"
      "sshd.service"
      "nginx.service"
    ];
    after = [
      "network-pre.target"
      "systemd-udevd.service"
    ];
    wants = [ "network-pre.target" ];

    path = [
      pkgs.iproute2
      pkgs.coreutils
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = configureNetworking;
    };

    unitConfig = {
      ConditionPathExists = "/sys/class/net/ens3";
    };
  };
}
