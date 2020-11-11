data "terraform_remote_state" "base" {
  backend = "local"

  config = {
    path = "../introducing-hashicups/terraform.tfstate"
  }
}

provider "google" {
  project     = data.terraform_remote_state.base.outputs.gcp_project
  region      = data.terraform_remote_state.base.outputs.gcp_region
  credentials = file(var.gcp_credentials)
}

locals {
  oidc_server_tag    = "oidc-server"
  oidc_discovery_url = "http://${module.oidc_server.public_ip}:9000"
  oidc_redirect_urls = ["${data.terraform_remote_state.base.outputs.consul_http_addr}/ui/oidc/callback", "http://localhost:8550/oidc/callback"]
}
