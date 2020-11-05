module "frontend_server" {
  source           = "git::https://github.com/timarenz/terraform-google-virtual-machine.git?ref=v0.2.3"
  project          = var.gcp_project
  environment_name = var.environment_name
  region           = var.gcp_region
  owner_name       = var.owner_name
  name             = "frontend-server"
  subnet           = module.gcp.subnets[0]
  username         = var.ssh_username
  ssh_public_key   = tls_private_key.ssh.public_key_openssh
  access_scopes = [
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring.write",
    "https://www.googleapis.com/auth/service.management.readonly",
    "https://www.googleapis.com/auth/servicecontrol",
    "https://www.googleapis.com/auth/compute.readonly"
  ]
}

resource "consul_acl_policy" "frontend_server" {
  depends_on = [module.consul_server_config, module.consul_server_firewall]
  name       = "frontend-server"
  rules      = <<-RULE
    node "frontend" {
      policy = "write"
    }
    RULE
}

resource "consul_acl_token" "frontend_server" {
  depends_on = [module.consul_server_config, module.consul_server_firewall]
  policies   = [consul_acl_policy.frontend_server.name]
}

data "consul_acl_token_secret_id" "frontend_server" {
  accessor_id = consul_acl_token.frontend_server.id
}

resource "consul_acl_policy" "frontend_service" {
  depends_on = [module.consul_server_config, module.consul_server_firewall]
  name       = "frontend-service"
  rules      = <<-RULE
    service "frontend" {
        policy = "write"
    }

    service "frontend-sidecar-proxy" {
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

    namespace "frontend-team" {

      service "frontend" {
        policy = "write"
      }

      service "frontend-sidecar-proxy" {
          policy = "write"
      }

    }
    RULE
}

resource "consul_acl_token" "frontend_service" {
  depends_on = [module.consul_server_config, module.consul_server_firewall]
  policies   = [consul_acl_policy.frontend_service.name]
}

data "consul_acl_token_secret_id" "frontend_service" {
  accessor_id = consul_acl_token.frontend_service.id
}

module "frontend_server_consul" {
  depends_on         = [consul_acl_token.frontend_server]
  source             = "git::https://github.com/timarenz/terraform-ssh-consul.git?ref=v0.6.1"
  host               = module.frontend_server.public_ip
  username           = var.ssh_username
  ssh_private_key    = tls_private_key.ssh.private_key_pem
  agent_type         = "client"
  retry_join         = ["provider=gce project_name=${var.gcp_project} tag_value=${local.consul_server_tag} zone_pattern=${var.gcp_region}-.*"]
  advertise_addr     = module.frontend_server.private_ip
  grpc_port          = 8502
  datacenter         = var.consul_primary_dc
  primary_datacenter = var.consul_primary_dc
  consul_version     = var.consul_version
  acl                = true
  agent_token        = data.consul_acl_token_secret_id.frontend_server.secret_id
  encryption_key     = random_id.consul_gossip_encryption_key.b64_std
  auto_encrypt       = true
}

resource "null_resource" "frontend_server" {
  depends_on = [module.frontend_server_consul]
  connection {
    type        = "ssh"
    user        = var.ssh_username
    private_key = tls_private_key.ssh.private_key_pem
    host        = module.frontend_server.public_ip
  }

  provisioner "remote-exec" {
    script = "${path.module}/scripts/install-docker.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/setup-frontend.sh"
    destination = "setup-frontend.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x setup-frontend.sh",
      "sudo CONSUL_HTTP_TOKEN=${data.consul_acl_token_secret_id.frontend_server.secret_id} CONSUL_SERVICE_TOKEN=${data.consul_acl_token_secret_id.frontend_service.secret_id} ./setup-frontend.sh"
    ]
  }
}
