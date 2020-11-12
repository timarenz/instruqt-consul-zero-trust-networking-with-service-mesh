provider "consul" {
  address    = "http://${data.terraform_remote_state.base.outputs.consul_server_public_ip}:8500"
  token      = data.terraform_remote_state.base.outputs.consul_master_token
  datacenter = data.terraform_remote_state.base.outputs.consul_primary_dc
}

resource "consul_intention" "default" {
  source_name           = "*"
  source_namespace      = "*"
  destination_name      = "*"
  destination_namespace = "*"
  action                = "deny"
}

resource "consul_intention" "public_to_product" {
  source_name      = "public"
  destination_name = "product"
  action           = "allow"
}

resource "consul_intention" "product_to_postgres" {
  source_name      = "product"
  destination_name = "postgres"
  action           = "deny"
}
