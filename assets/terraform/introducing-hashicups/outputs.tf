output "consul_server_public_ip" {
  value = module.consul_server.public_ip
}

output "frontend_server_public_ip" {
  value = module.frontend_server.public_ip
}

output "oidc_server_public_ip" {
  value = module.oidc_server.public_ip
}

output "postgres_server_public_ip" {
  value = module.postgres_server.public_ip
}

output "product_server_public_ip" {
  value = module.product_server.public_ip
}

output "public_server_public_ip" {
  value = module.public_server.public_ip
}

output "consul_master_token" {
  value = random_uuid.consul_master_token.result
}

output "frontend_server_token" {
  value = data.consul_acl_token_secret_id.frontend_server.secret_id
}

output "frontend_service_token" {
  value = data.consul_acl_token_secret_id.frontend_service.secret_id
}

output "postgres_server_token" {
  value = data.consul_acl_token_secret_id.postgres_server.secret_id
}

output "postgres_service_token" {
  value = data.consul_acl_token_secret_id.postgres_service.secret_id
}

output "product_server_token" {
  value = data.consul_acl_token_secret_id.product_server.secret_id
}

output "product_service_token" {
  value = data.consul_acl_token_secret_id.product_service.secret_id
}

output "public_server_token" {
  value = data.consul_acl_token_secret_id.public_server.secret_id
}

output "public_service_token" {
  value = data.consul_acl_token_secret_id.public_service.secret_id
}

output "ssh_private_key" {
  value = tls_private_key.ssh.private_key_pem
}

output "ssh_public_key" {
  value = tls_private_key.ssh.public_key_openssh
}

output "ssh_username" {
  value = var.ssh_username
}

output "consul_server_tag" {
  value = local.consul_server_tag
}

output "consul_primary_dc" {
  value = var.consul_primary_dc
}

output "consul_http_addr" {
  value = local.consul_http_addr
}

output "consul_version" {
  value = var.consul_version
}

output "gcp_project" {
  value = module.gcp.project_id
}

output "gcp_region" {
  value = module.gcp.region
}

output "gcp_network" {
  value = module.gcp.network
}

output "gcp_subnet" {
  value = module.gcp.subnets[0]
}

output "environment_name" {
  value = var.environment_name
}

output "owner_name" {
  value = var.owner_name
}
