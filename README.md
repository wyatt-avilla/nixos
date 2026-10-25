# NixOS Configuration

My NixOS system configuration. My Home Manager configuration is
[here](https://github.com/wyatt-avilla/home-manager).

## Hosts

This configuration defines 4 hosts.

1. [desktop](https://github.com/wyatt-avilla/nixos/tree/main/hosts/desktop)
2. [laptop](https://github.com/wyatt-avilla/nixos/tree/main/hosts/laptop)
3. [homelab](https://github.com/wyatt-avilla/nixos/tree/main/hosts/homelab)
4. [vps](https://github.com/wyatt-avilla/nixos/tree/main/hosts/vps)

The VPS is a small Digital Ocean droplet, a configurable custom ISO can be built with:

```sh
nix run .#build-vps-image
```
