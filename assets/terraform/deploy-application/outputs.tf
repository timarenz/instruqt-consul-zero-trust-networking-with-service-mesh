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

output "ssh_username" {
  value = var.ssh_username
}

output "consul_primary_dc" {
  value = var.consul_primary_dc
}
