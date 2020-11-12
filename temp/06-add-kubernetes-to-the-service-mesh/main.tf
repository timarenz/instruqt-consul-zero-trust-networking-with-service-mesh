data "terraform_remote_state" "base" {
  backend = "local"

  config = {
    path = "../01-introducing-hashicups/terraform.tfstate"
  }
}

provider "google" {
  project     = var.gcp_project
  region      = data.terraform_remote_state.base.outputs.gcp_region
  credentials = file(var.gcp_credentials)
}

provider "google" {
  alias       = "on-prem"
  project     = data.terraform_remote_state.base.outputs.gcp_project
  region      = data.terraform_remote_state.base.outputs.gcp_region
  credentials = file(data.terraform_remote_state.base.outputs.gcp_credentials)
}

data "google_client_config" "client" {}

module "gcp" {
  source           = "git::https://github.com/timarenz/terraform-google-environment.git?ref=v0.2.4"
  region           = data.terraform_remote_state.base.outputs.gcp_region
  project          = var.gcp_project
  environment_name = data.terraform_remote_state.base.outputs.environment_name
  subnets = [
    {
      name   = "subnet-1"
      prefix = "172.16.40.0/24"
    }
  ]
}

locals {
  mesh_gateway_tag = "mesh-gateway"
}
