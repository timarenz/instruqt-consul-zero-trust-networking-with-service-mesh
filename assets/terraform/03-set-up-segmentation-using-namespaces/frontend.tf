resource "null_resource" "frontend_server" {
  connection {
    type        = "ssh"
    user        = data.terraform_remote_state.base.outputs.ssh_username
    private_key = data.terraform_remote_state.base.outputs.ssh_private_key
    host        = data.terraform_remote_state.base.outputs.frontend_server_public_ip
  }

  provisioner "file" {
    source      = "${path.module}/scripts/setup-frontend.sh"
    destination = "setup-frontend.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x setup-frontend.sh",
      "sudo CONSUL_SERVICE_TOKEN=${data.terraform_remote_state.base.outputs.frontend_service_token} ./setup-frontend.sh"
    ]
  }
}

resource "null_resource" "frontend_server_solve" {
  depends_on = [null_resource.frontend_server]
  count      = var.solve == true ? 1 : 0
  connection {
    type        = "ssh"
    user        = data.terraform_remote_state.base.outputs.ssh_username
    private_key = data.terraform_remote_state.base.outputs.ssh_private_key
    host        = data.terraform_remote_state.base.outputs.frontend_server_public_ip
  }

  provisioner "file" {
    source      = "${path.module}/scripts/solve-frontend.sh"
    destination = "solve-frontend.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x solve-frontend.sh",
      "sudo CONSUL_SERVICE_TOKEN=${data.terraform_remote_state.base.outputs.frontend_service_token} ./solve-frontend.sh"
    ]
  }
}
