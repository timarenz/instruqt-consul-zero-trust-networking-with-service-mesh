data "terraform_remote_state" "base" {
  backend = "local"

  config = {
    path = "../deploy-application/terraform.tfstate"
  }
}

locals {
  oidc_server_tag    = "oidc-server"
  oidc_discovery_url = "http://${module.oidc_server.public_ip}:9000"
  oidc_redirect_urls = ["${data.terraform_remote_state.base.outputs.consul_http_addr}/ui/oidc/callback", "http://localhost:8550/oidc/callback"]
}
