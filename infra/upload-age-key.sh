#!/usr/bin/env bash
set -euo pipefail
mkdir -p var/lib/sops-nix
cp "$HOME/.config/sops/age/keys.txt" var/lib/sops-nix/key.txt
chmod 600 var/lib/sops-nix/key.txt
