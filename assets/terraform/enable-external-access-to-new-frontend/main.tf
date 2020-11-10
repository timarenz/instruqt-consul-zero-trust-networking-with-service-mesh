data "terraform_remote_state" "base" {
  backend = "local"

  config = {
    path = "../introducing-hashicups/terraform.tfstate"
  }
}

data "terraform_remote_state" "k8s" {
  backend = "local"

  config = {
    path = "../add-kubernetes-to-the-service-mesh/terraform.tfstate"
  }
}

provider "consul" {
  address    = data.terraform_remote_state.base.outputs.consul_http_addr
  token      = data.terraform_remote_state.base.outputs.consul_master_token
  datacenter = data.terraform_remote_state.base.outputs.consul_primary_dc
}

resource "consul_config_entry" "ingress_gateway" {
  name = "ingress-gateway"
  kind = "ingress-gateway"

  config_json = jsonencode({
    Listeners = [{
      Port     = 8080
      Protocol = "tcp"
      Services = [{
        Name      = "frontend"
        Namespace = "frontend-team"
      }]
    }]
  })
}

provider "kubernetes" {
  config_path = data.terraform_remote_state.k8s.outputs.kubeconfig_file
}

data "kubernetes_service" "consul_ingress_gateway" {
  metadata {
    name      = "consul-ingress-gateway"
    namespace = data.terraform_remote_state.k8s.outputs.kubernetes_namespaces_consul
  }
}

resource "consul_intention" "ingress_to_frontend" {
  count                 = var.solve == true ? 1 : 0
  source_name           = "ingress-gateway"
  source_namespace      = "default"
  destination_name      = "frontend"
  destination_namespace = "frontend-team"
  action                = "allow"
}
