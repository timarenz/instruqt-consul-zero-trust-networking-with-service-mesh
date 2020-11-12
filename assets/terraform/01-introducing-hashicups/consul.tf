module "consul_server_firewall" {
  source           = "git::https://github.com/timarenz/terraform-google-firewall.git?ref=v0.1.1"
  project          = var.gcp_project
  environment_name = var.environment_name
  name             = "consul-server"
  network          = module.gcp.network
  allow_rules = [{
    protocol = "tcp"
    ports    = ["8500"]
  }]
  target_tags = [local.consul_server_tag]
}

module "consul_server" {
  source           = "git::https://github.com/timarenz/terraform-google-virtual-machine.git?ref=v0.2.3"
  project          = var.gcp_project
  environment_name = var.environment_name
  region           = var.gcp_region
  owner_name       = var.owner_name
  name             = "consul-server"
  subnet           = module.gcp.subnets[0]
  username         = var.ssh_username
  ssh_public_key   = tls_private_key.ssh.public_key_openssh
  network_tags     = [local.consul_server_tag]
  access_scopes = [
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring.write",
    "https://www.googleapis.com/auth/service.management.readonly",
    "https://www.googleapis.com/auth/servicecontrol",
    "https://www.googleapis.com/auth/compute.readonly"
  ]
}

resource "random_uuid" "consul_master_token" {}

resource "random_id" "consul_gossip_encryption_key" {
  byte_length = 32
}

module "consul_server_cert" {
  source                  = "git::https://github.com/timarenz/terraform-tls-certificate?ref=v0.2.0"
  private_key_algorithm   = "ECDSA"
  private_key_ecdsa_curve = "P256"
  ca_cert                 = module.root_ca.cert
  ca_key                  = module.root_ca.private_key
  ca_key_algorithm        = module.root_ca.key_algorithm
  organization_name       = "Tim Arenz"
  common_name             = "server.on-prem.consul"
  allowed_uses            = ["key_encipherment", "digital_signature", "server_auth", "client_auth"]
  dns_names               = ["localhost", "consul-server.server.${var.consul_primary_dc}.consul"]
  ip_addresses            = ["127.0.0.1", module.consul_server.public_ip, module.consul_server.private_ip]
}


module "consul_server_config" {
  source                             = "git::https://github.com/timarenz/terraform-ssh-consul.git?ref=v0.6.3"
  host                               = module.consul_server.public_ip
  username                           = var.ssh_username
  ssh_private_key                    = tls_private_key.ssh.private_key_pem
  retry_join                         = ["provider=gce project_name=${var.gcp_project} tag_value=${local.consul_server_tag} zone_pattern=${var.gcp_region}-.*"]
  connect                            = true
  advertise_addr                     = module.consul_server.private_ip
  datacenter                         = var.consul_primary_dc
  primary_datacenter                 = var.consul_primary_dc
  bootstrap_expect                   = 1
  consul_version                     = var.consul_version
  acl                                = true
  master_token                       = random_uuid.consul_master_token.result
  agent_token                        = random_uuid.consul_master_token.result
  enable_mesh_gateway_wan_federation = true
  encryption_key                     = random_id.consul_gossip_encryption_key.b64_std
  ca_file                            = module.root_ca.cert
  cert_file                          = module.consul_server_cert.cert
  key_file                           = module.consul_server_cert.private_key
  #   auto_encrypt                       = true
  #   verify_incoming                    = true
  #   verify_outgoing                    = true
  #   verify_server_hostname             = true
  audit_log = true
}

provider "consul" {
  address    = "http://${module.consul_server.public_ip}:8500"
  token      = random_uuid.consul_master_token.result
  datacenter = var.consul_primary_dc
}

resource "consul_acl_policy" "anonymous" {
  depends_on = [module.consul_server_config]
  name       = "anonymous"
  rules      = <<-RULE
    namespace_prefix "" {

      service_prefix "" {
          policy = "read"
      }

      node_prefix "" {
          policy = "read"
      }

    }
    RULE
}

resource "consul_acl_token_policy_attachment" "anonymous" {
  depends_on = [module.consul_server_config, module.consul_server_firewall]
  token_id   = "00000000-0000-0000-0000-000000000002"
  policy     = consul_acl_policy.anonymous.name
}
