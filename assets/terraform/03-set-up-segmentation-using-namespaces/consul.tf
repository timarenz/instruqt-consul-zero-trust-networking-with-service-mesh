provider "consul" {
  address    = "http://${data.terraform_remote_state.base.outputs.consul_server_public_ip}:8500"
  token      = data.terraform_remote_state.base.outputs.consul_master_token
  datacenter = data.terraform_remote_state.base.outputs.consul_primary_dc
}

resource "consul_namespace" "api" {
  name        = "api-team"
  description = "Namespace for api-team managing the api services"
}

resource "consul_namespace" "db" {
  name        = "db-team"
  description = "Namespace for db-team managing the db services"
}

resource "consul_intention" "api" {
  source_name           = "*"
  source_namespace      = consul_namespace.api.name
  destination_name      = "*"
  destination_namespace = consul_namespace.api.name
  action                = "allow"
}

resource "consul_intention" "product_db" {
  source_name           = "product"
  source_namespace      = consul_namespace.api.name
  destination_name      = "postgres"
  destination_namespace = consul_namespace.db.name
  action                = "allow"
}
