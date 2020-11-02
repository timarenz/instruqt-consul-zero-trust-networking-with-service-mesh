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

module "consul_server_config" {
  source                             = "git::https://github.com/timarenz/terraform-ssh-consul.git?ref=v0.6.2"
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
