resource "null_resource" "postgres_server" {
  connection {
    type        = "ssh"
    user        = data.terraform_remote_state.base.outputs.ssh_username
    private_key = data.terraform_remote_state.base.outputs.ssh_private_key
    host        = data.terraform_remote_state.base.outputs.postgres_server_public_ip
  }

  provisioner "remote-exec" {
    script = "${path.module}/scripts/install-envoy.sh"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/setup-postgres.sh"
    destination = "setup-postgres.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x setup-postgres.sh",
      "sudo CONSUL_SERVICE_TOKEN=${data.terraform_remote_state.base.outputs.postgres_service_token} ./setup-postgres.sh"
    ]
  }
}

resource "null_resource" "postgres_server_solve" {
  depends_on = [null_resource.postgres_server]
  count      = var.solve == true ? 1 : 0

  connection {
    type        = "ssh"
    user        = data.terraform_remote_state.base.outputs.ssh_username
    private_key = data.terraform_remote_state.base.outputs.ssh_private_key
    host        = data.terraform_remote_state.base.outputs.postgres_server_public_ip
  }

  provisioner "file" {
    source      = "${path.module}/scripts/solve-postgres.sh"
    destination = "solve-postgres.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x solve-postgres.sh",
      "sudo CONSUL_SERVICE_TOKEN=${data.terraform_remote_state.base.outputs.postgres_service_token} ./solve-postgres.sh"
    ]
  }
}
