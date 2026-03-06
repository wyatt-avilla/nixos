terraform {
  required_providers {
    digitalocean = {
      source  = "registry.opentofu.org/digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}
