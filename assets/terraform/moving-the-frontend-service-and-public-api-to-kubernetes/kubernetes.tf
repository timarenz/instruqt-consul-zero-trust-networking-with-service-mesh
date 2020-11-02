module "k8s" {
  source           = "git::https://github.com/timarenz/terraform-google-kubernetes.git?ref=v0.5.1"
  project          = module.gcp.project_id
  environment_name = data.terraform_remote_state.base.outputs.environment_name
  owner_name       = data.terraform_remote_state.base.outputs.owner_name
  name             = "k8s"
  network          = module.gcp.network
  subnet           = module.gcp.subnet_self_links[0]
  region           = module.gcp.region
  node_count       = 1
  oauth_scopes = [
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/cloud-platform"
  ]
}

provider "kubernetes" {
  host                   = module.k8s.endpoint
  cluster_ca_certificate = module.k8s.cluster_ca_certificate
  token                  = data.google_client_config.client.access_token

  load_config_file = false
}
