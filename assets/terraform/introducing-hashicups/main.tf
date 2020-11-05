provider "google" {
  project     = var.gcp_project
  region      = var.gcp_region
  credentials = file(var.gcp_credentials)
}

data "google_client_config" "client" {}

resource "tls_private_key" "ssh" {
  algorithm   = "RSA"
  ecdsa_curve = "4096"
}

locals {
  consul_server_tag = "consul-server"
  consul_http_addr  = "http://${module.consul_server.public_ip}:8500"
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

module "root_ca" {
  source                  = "git::https://github.com/timarenz/terraform-tls-root-ca.git?ref=v0.2.1"
  private_key_algorithm   = "ECDSA"
  private_key_ecdsa_curve = "P256"
  organization_name       = "HashiCorp Example"
  common_name             = "Root CA"
  allowed_uses            = ["digital_signature", "cert_signing", "crl_signing"]
}
