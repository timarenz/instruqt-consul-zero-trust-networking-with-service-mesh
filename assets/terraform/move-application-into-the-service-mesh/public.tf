resource "null_resource" "public_server" {
  connection {
    type        = "ssh"
    user        = data.terraform_remote_state.base.outputs.ssh_username
    private_key = data.terraform_remote_state.base.outputs.ssh_private_key
    host        = data.terraform_remote_state.base.outputs.public_server_public_ip
  }

  provisioner "file" {
    source      = "${path.module}/scripts/setup-public.sh"
    destination = "setup-public.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x setup-public.sh",
      "sudo CONSUL_SERVICE_TOKEN=${data.terraform_remote_state.base.outputs.public_service_token} ./setup-public.sh"
    ]
  }
}
