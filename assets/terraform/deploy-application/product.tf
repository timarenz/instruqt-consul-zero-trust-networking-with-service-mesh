
module "product_server" {
  source           = "git::https://github.com/timarenz/terraform-google-virtual-machine.git?ref=v0.2.3"
  project          = var.gcp_project
  environment_name = var.environment_name
  region           = var.gcp_region
  owner_name       = var.owner_name
  name             = "product-server"
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

resource "consul_acl_policy" "product_server" {
  depends_on = [module.consul_server_config, module.consul_server_firewall]
  name       = "product-server"
  rules      = <<-RULE
    node "product" {
      policy = "write"
    }
    RULE
}

resource "consul_acl_token" "product_server" {
  depends_on = [module.consul_server_config, module.consul_server_firewall]
  policies   = [consul_acl_policy.product_server.name]
}

data "consul_acl_token_secret_id" "product_server" {
  accessor_id = consul_acl_token.product_server.id
}

resource "consul_acl_policy" "product_service" {
  depends_on = [module.consul_server_config, module.consul_server_firewall]
  name       = "product-service"
  rules      = <<-RULE
    service "product" {
        policy = "write"
    }

    service "product-sidecar-proxy" {
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

    namespace "api-team" {

      service "product" {
        policy = "write"
      }

      service "product-sidecar-proxy" {
          policy = "write"
      }

    }
    RULE
}

resource "consul_acl_token" "product_service" {
  depends_on = [module.consul_server_config, module.consul_server_firewall]
  policies   = [consul_acl_policy.product_service.name]
}

data "consul_acl_token_secret_id" "product_service" {
  accessor_id = consul_acl_token.product_service.id
}

module "product_server_consul" {
  depends_on         = [consul_acl_token.product_server]
  source             = "/Users/tim/Dropbox (Personal)/dev/terraform-modules/terraform-ssh-consul"
  host               = module.product_server.public_ip
  username           = var.ssh_username
  ssh_private_key    = tls_private_key.ssh.private_key_pem
  agent_type         = "client"
  retry_join         = ["provider=gce project_name=${var.gcp_project} tag_value=${local.consul_server_tag} zone_pattern=${var.gcp_region}-.*"]
  advertise_addr     = module.product_server.private_ip
  grpc_port          = 8502
  datacenter         = var.consul_primary_dc
  primary_datacenter = var.consul_primary_dc
  consul_version     = "1.8.4+ent"
  acl                = true
  agent_token        = data.consul_acl_token_secret_id.product_server.secret_id
}

resource "null_resource" "product_server" {
  depends_on = [module.product_server_consul]
  connection {
    type        = "ssh"
    user        = var.ssh_username
    private_key = tls_private_key.ssh.private_key_pem
    host        = module.product_server.public_ip
  }

  provisioner "remote-exec" {
    script = "${path.module}/scripts/install-docker.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/setup-product.sh"
    destination = "setup-product.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x setup-product.sh",
      "sudo CONSUL_HTTP_TOKEN=${data.consul_acl_token_secret_id.product_server.secret_id} CONSUL_SERVICE_TOKEN=${data.consul_acl_token_secret_id.product_service.secret_id} ./setup-product.sh"
    ]
  }
}
