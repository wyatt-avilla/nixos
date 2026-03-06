variable "do_token" {
  type      = string
  sensitive = true
}

variable "droplet_size" {
  type = string
}

variable "ssh_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}
