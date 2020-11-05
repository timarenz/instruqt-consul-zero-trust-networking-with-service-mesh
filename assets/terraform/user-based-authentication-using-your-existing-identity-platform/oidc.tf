module "oidc_server_firewall" {
  source           = "git::https://github.com/timarenz/terraform-google-firewall.git?ref=v0.1.1"
  project          = data.terraform_remote_state.base.outputs.gcp_project
  environment_name = data.terraform_remote_state.base.outputs.environment_name
  name             = "oidc-server"
  network          = data.terraform_remote_state.base.outputs.gcp_network
  allow_rules = [{
    protocol = "tcp"
    ports    = ["9000"]
  }]
  target_tags = [local.oidc_server_tag]
}

module "oidc_server" {
  source           = "git::https://github.com/timarenz/terraform-google-virtual-machine.git?ref=v0.2.3"
  project          = data.terraform_remote_state.base.outputs.gcp_project
  environment_name = data.terraform_remote_state.base.outputs.environment_name
  region           = data.terraform_remote_state.base.outputs.gcp_region
  owner_name       = data.terraform_remote_state.base.outputs.owner_name
  name             = "oidc-server"
  subnet           = data.terraform_remote_state.base.outputs.gcp_subnet
  username         = data.terraform_remote_state.base.outputs.ssh_username
  ssh_public_key   = data.terraform_remote_state.base.outputs.ssh_public_key
  network_tags     = [local.oidc_server_tag]
  access_scopes = [
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring.write",
    "https://www.googleapis.com/auth/service.management.readonly",
    "https://www.googleapis.com/auth/servicecontrol",
    "https://www.googleapis.com/auth/compute.readonly"
  ]
}

provider "consul" {
  address    = data.terraform_remote_state.base.outputs.consul_http_addr
  token      = data.terraform_remote_state.base.outputs.consul_master_token
  datacenter = data.terraform_remote_state.base.outputs.consul_primary_dc
}

resource "consul_acl_policy" "oidc_server" {
  name  = "oidc-server"
  rules = <<-RULE
    node "oidc" {
      policy = "write"
    }
    RULE
}

resource "consul_acl_token" "oidc_server" {
  policies = [consul_acl_policy.oidc_server.name]
}

data "consul_acl_token_secret_id" "oidc_server" {
  accessor_id = consul_acl_token.oidc_server.id
}

resource "consul_acl_policy" "oidc_service" {
  name  = "oidc-service"
  rules = <<-RULE
    service "oidc" {
        policy = "write"
    }

    service "oidc-sidecar-proxy" {
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

resource "consul_acl_token" "oidc_service" {
  policies = [consul_acl_policy.oidc_service.name]
}

data "consul_acl_token_secret_id" "oidc_service" {
  accessor_id = consul_acl_token.oidc_service.id
}

module "oidc_server_consul" {
  source             = "git::https://github.com/timarenz/terraform-ssh-consul.git?ref=v0.6.1"
  host               = module.oidc_server.public_ip
  username           = data.terraform_remote_state.base.outputs.ssh_username
  ssh_private_key    = data.terraform_remote_state.base.outputs.ssh_private_key
  agent_type         = "client"
  retry_join         = ["provider=gce project_name=${data.terraform_remote_state.base.outputs.gcp_project} tag_value=${data.terraform_remote_state.base.outputs.consul_server_tag} zone_pattern=${data.terraform_remote_state.base.outputs.gcp_region}-.*"]
  advertise_addr     = module.oidc_server.private_ip
  grpc_port          = 8502
  datacenter         = data.terraform_remote_state.base.outputs.consul_primary_dc
  primary_datacenter = data.terraform_remote_state.base.outputs.consul_primary_dc
  consul_version     = data.terraform_remote_state.base.outputs.consul_version
  acl                = true
  agent_token        = data.consul_acl_token_secret_id.oidc_server.secret_id
  encryption_key     = data.terraform_remote_state.base.outputs.consul_gossip_encryption_key
}

resource "null_resource" "oidc_server" {
  depends_on = [module.oidc_server_consul]
  connection {
    type        = "ssh"
    user        = data.terraform_remote_state.base.outputs.ssh_username
    private_key = data.terraform_remote_state.base.outputs.ssh_private_key
    host        = module.oidc_server.public_ip
  }

  provisioner "remote-exec" {
    script = "${path.module}/scripts/install-docker.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/setup-oidc.sh"
    destination = "setup-oidc.sh"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/oidc-config.json.tpl", {
      oidc_discovery_url = local.oidc_discovery_url
      oidc_redirect_url1 = local.oidc_redirect_urls[0]
      oidc_redirect_url2 = local.oidc_redirect_urls[1]
    })
    destination = "/tmp/oidc-config.json"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x setup-oidc.sh",
      "sudo CONSUL_HTTP_TOKEN=${data.terraform_remote_state.base.outputs.consul_master_token} CONSUL_SERVICE_TOKEN=${data.consul_acl_token_secret_id.oidc_service.secret_id} ./setup-oidc.sh"
    ]
  }
}

resource "consul_acl_auth_method" "oidc" {
  depends_on    = [null_resource.oidc_server, module.oidc_server_firewall]
  name          = "auth_method"
  type          = "oidc"
  max_token_ttl = "60m"
  config_json = jsonencode({
    "VerboseOIDCLogging" : true,
    "OIDCDiscoveryURL" : local.oidc_discovery_url,
    "OIDCClientID" : "foo",
    "OIDCClientSecret" : "bar",
    "BoundAudiences" : ["foo"],
    "AllowedRedirectURIs" : [
      local.oidc_redirect_urls[0],
      local.oidc_redirect_urls[1]
    ],
    "ClaimMappings" : {
      "name" : "first_name",
      "email" : "email"
    },
    "ListClaimMappings" : {
      "groups" : "groups"
    }
  })
}

resource "consul_acl_binding_rule" "admin" {
  depends_on  = [null_resource.oidc_server]
  auth_method = consul_acl_auth_method.oidc.name
  description = "admin"
  selector    = "admin in list.groups"
  bind_type   = "role"
  bind_name   = "admin"
}

resource "consul_acl_binding_rule" "db_team" {
  depends_on  = [null_resource.oidc_server]
  auth_method = consul_acl_auth_method.oidc.name
  description = "db-team"
  selector    = "\"db-team\" in list.groups"
  bind_type   = "role"
  bind_name   = "db-team"
}

resource "consul_acl_binding_rule" "api_team" {
  depends_on  = [null_resource.oidc_server]
  auth_method = consul_acl_auth_method.oidc.name
  description = "api-team"
  selector    = "\"api-team\" in list.groups"
  bind_type   = "role"
  bind_name   = "api-team"
}

resource "consul_acl_binding_rule" "frontend_team" {
  depends_on  = [null_resource.oidc_server]
  auth_method = consul_acl_auth_method.oidc.name
  description = "frontend-team"
  selector    = "\"frontend-team\" in list.groups"
  bind_type   = "role"
  bind_name   = "frontend-team"
}

resource "consul_acl_policy" "db_team" {
  depends_on = [null_resource.oidc_server]
  name       = "db-team"
  rules      = <<-RULE
    service_prefix "" {
        policy = "read"
    }

    node_prefix "" {
        policy = "read"
    }

    namespace_prefix "db-team" {

      service_prefix "" {
          policy = "read"
          intentions = "write"
      }

    }
    RULE
}

resource "consul_acl_role" "db_team" {
  depends_on = [null_resource.oidc_server]
  name       = "db-team"

  policies = [consul_acl_policy.db_team.id]
}

resource "consul_acl_policy" "api_team" {
  depends_on = [null_resource.oidc_server]
  name       = "api-team"
  rules      = <<-RULE
    service_prefix "" {
        policy = "read"
    }

    node_prefix "" {
        policy = "read"
    }

    namespace_prefix "api-team" {

      service_prefix "" {
          policy = "read"
          intentions = "write"
      }

    }
    RULE
}

resource "consul_acl_role" "api_team" {
  depends_on = [null_resource.oidc_server]
  name       = "api-team"

  policies = [consul_acl_policy.api_team.id]
}

resource "consul_acl_policy" "frontend_team" {
  depends_on = [null_resource.oidc_server]
  name       = "frontend-team"
  rules      = <<-RULE
    service_prefix "" {
        policy = "read"
    }

    node_prefix "" {
        policy = "read"
    }

    namespace_prefix "frontend-team" {

      service_prefix "" {
          policy = "read"
          intentions = "write"
      }

    }
    RULE
}

resource "consul_acl_role" "frontend_team" {
  depends_on = [null_resource.oidc_server]
  name       = "frontend-team"

  policies = [consul_acl_policy.frontend_team.id]
}

resource "consul_acl_role" "admin" {
  depends_on = [null_resource.oidc_server]
  name       = "admin"

  policies = ["00000000-0000-0000-0000-000000000001"]
}
