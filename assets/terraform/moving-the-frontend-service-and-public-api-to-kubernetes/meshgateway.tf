module "mesh_gateway_firewall" {
  providers = {
    google = google.on-prem
  }
  source           = "git::https://github.com/timarenz/terraform-google-firewall.git?ref=v0.1.1"
  project          = data.terraform_remote_state.base.outputs.gcp_project
  environment_name = data.terraform_remote_state.base.outputs.environment_name
  name             = "mesh-gateway"
  network          = data.terraform_remote_state.base.outputs.environment_name
  allow_rules = [{
    protocol = "tcp"
    ports    = ["8443"]
  }]
  target_tags = [local.mesh_gateway_tag]
}

module "mesh_gateway" {
  providers = {
    google = google.on-prem
  }
  source           = "git::https://github.com/timarenz/terraform-google-virtual-machine.git?ref=v0.2.3"
  project          = data.terraform_remote_state.base.outputs.gcp_project
  environment_name = data.terraform_remote_state.base.outputs.environment_name
  region           = data.terraform_remote_state.base.outputs.gcp_region
  owner_name       = data.terraform_remote_state.base.outputs.owner_name
  name             = "mesh-gateway"
  subnet           = data.terraform_remote_state.base.outputs.gcp_subnet
  username         = data.terraform_remote_state.base.outputs.ssh_username
  ssh_public_key   = data.terraform_remote_state.base.outputs.ssh_public_key
  network_tags     = [local.mesh_gateway_tag]
  access_scopes = [
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring.write",
    "https://www.googleapis.com/auth/service.management.readonly",
    "https://www.googleapis.com/auth/servicecontrol",
    "https://www.googleapis.com/auth/compute.readonly"
  ]
}

resource "consul_acl_policy" "mesh_gateway" {
  name  = "mesh-gateway"
  rules = <<-RULE
    node "mesh-gateway" {
      policy = "write"
    }
    RULE
}

resource "consul_acl_token" "mesh_gateway" {
  policies = [consul_acl_policy.mesh_gateway.name]
}

data "consul_acl_token_secret_id" "mesh_gateway" {
  accessor_id = consul_acl_token.mesh_gateway.id
}

resource "consul_acl_policy" "mesh_gateway_service" {
  name  = "mesh-gateway"
  rules = <<-RULE
    service "mesh-gateway" {
        policy = "write"
    }

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

resource "consul_acl_token" "mesh_gateway_service" {
  policies = [consul_acl_policy.mesh_gateway_service.name]
}

data "consul_acl_token_secret_id" "mesh_gateway_service" {
  accessor_id = consul_acl_token.mesh_gateway_service.id
}

resource "consul_config_entry" "mesh_gateway" {
  name = "proxy-defaults"
  kind = "global"

  config_json = jsonencode({
    MeshGateway = {
      Mode = "local"
    }
  })
}

module "mesh_gateway_consul" {
  source             = "git::https://github.com/timarenz/terraform-ssh-consul.git?ref=v0.6.2"
  host               = module.mesh_gateway.public_ip
  username           = data.terraform_remote_state.base.outputs.ssh_username
  ssh_private_key    = data.terraform_remote_state.base.outputs.ssh_private_key
  agent_type         = "client"
  retry_join         = ["provider=gce project_name=${data.terraform_remote_state.base.outputs.gcp_project} tag_value=${data.terraform_remote_state.base.outputs.consul_server_tag} zone_pattern=${data.terraform_remote_state.base.outputs.gcp_region}-.*"]
  advertise_addr     = module.mesh_gateway.private_ip
  grpc_port          = 8502
  datacenter         = data.terraform_remote_state.base.outputs.consul_primary_dc
  primary_datacenter = data.terraform_remote_state.base.outputs.consul_primary_dc
  consul_version     = data.terraform_remote_state.base.outputs.consul_version
  acl                = true
  agent_token        = data.consul_acl_token_secret_id.mesh_gateway.secret_id
}

resource "null_resource" "mesh_gateway" {
  depends_on = [module.mesh_gateway_consul]
  connection {
    type        = "ssh"
    user        = data.terraform_remote_state.base.outputs.ssh_username
    private_key = data.terraform_remote_state.base.outputs.ssh_private_key
    host        = module.mesh_gateway.public_ip
  }

  provisioner "remote-exec" {
    script = "${path.module}/scripts/install-envoy.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/setup-mesh-gateway.sh"
    destination = "setup-mesh-gateway.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x setup-mesh-gateway.sh",
      "sudo CONSUL_SERVICE_TOKEN=${data.consul_acl_token_secret_id.mesh_gateway_service.secret_id}  MESH_GATEWAY_PRIVATE_IP=${module.mesh_gateway.private_ip} MESH_GATEWAY_PUBLIC_IP=${module.mesh_gateway.public_ip} ./setup-mesh-gateway.sh"
    ]
  }
}
