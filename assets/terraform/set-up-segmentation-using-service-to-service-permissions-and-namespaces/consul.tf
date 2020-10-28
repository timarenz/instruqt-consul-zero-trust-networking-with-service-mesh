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

# resource "consul_intention" "default" {
#   source_name           = "*"
#   source_namespace      = "*"
#   destination_name      = "*"
#   destination_namespace = "*"
#   action                = "deny"
# }

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

resource "consul_namespace" "frontend" {
  count       = var.solve == true ? 1 : 0
  name        = "frontend-team"
  description = "Namespace for frontend-team managing the frontend application"
}

resource "consul_intention" "frontend_public" {
  count                 = var.solve == true ? 1 : 0
  source_name           = "frontend"
  source_namespace      = consul_namespace.frontend[0].name
  destination_name      = "public"
  destination_namespace = consul_namespace.api.name
  action                = "deny"
}
