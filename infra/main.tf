data "digitalocean_ssh_key" "desktop" {
  name = "desktop"
}

resource "digitalocean_droplet" "vps" {
  name     = "nixos-vps"
  region   = "sfo3"
  size     = var.droplet_size
  image    = "debian-12-x64"
  ssh_keys = [data.digitalocean_ssh_key.desktop.fingerprint]
}

module "nixos_anywhere" {
  source = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"

  nixos_system_attr      = ".#nixosConfigurations.vps.config.system.build.toplevel"
  nixos_partitioner_attr = ".#nixosConfigurations.vps.config.system.build.diskoScript"

  target_host = digitalocean_droplet.vps.ipv4_address
  instance_id = digitalocean_droplet.vps.id

  extra_files_script = "${path.module}/upload-age-key.sh"
}
