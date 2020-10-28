provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

data "google_client_config" "client" {}

resource "tls_private_key" "ssh" {
  algorithm   = "RSA"
  ecdsa_curve = "4096"
}

locals {
  consul_server_tag  = "consul-server"
  oidc_server_tag    = "oidc-server"
  oidc_discovery_url = "http://${module.oidc_server.public_ip}:9000"
  oidc_redirect_urls = ["http://${module.consul_server.public_ip}:8500/ui/oidc/callback", "http://localhost:8550/oidc/callback"]
}

resource "local_file" "ssh" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/ssh.key"
  file_permission = "0400"
}

module "gcp" {
  source           = "git::https://github.com/timarenz/terraform-google-environment.git?ref=v0.2.4"
  region           = var.gcp_region
  project          = var.gcp_project
  environment_name = var.environment_name
  subnets = [
    {
      name   = "subnet-1"
      prefix = "192.168.40.0/24"
    }
  ]
}
