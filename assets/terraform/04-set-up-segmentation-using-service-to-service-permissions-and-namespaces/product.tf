resource "null_resource" "product_server" {
  connection {
    type        = "ssh"
    user        = data.terraform_remote_state.base.outputs.ssh_username
    private_key = data.terraform_remote_state.base.outputs.ssh_private_key
    host        = data.terraform_remote_state.base.outputs.product_server_public_ip
  }

  provisioner "file" {
    source      = "${path.module}/scripts/setup-product.sh"
    destination = "setup-product.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x setup-product.sh",
      "sudo CONSUL_SERVICE_TOKEN=${data.terraform_remote_state.base.outputs.product_service_token} ./setup-product.sh"
    ]
  }
}
