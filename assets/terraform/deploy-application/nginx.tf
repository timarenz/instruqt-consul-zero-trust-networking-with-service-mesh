resource "local_file" "nginx_consul" {
  content = templatefile("${path.module}/templates/nginx-consul.conf.tpl", {
    consul_http_addr = local.consul_http_addr
  })
  filename = "/etc/nginx/conf.d/consul.conf"
}

resource "null_resource" "nginx_consul" {
  depends_on = [local_file.nginx_consul]

  provisioner "local-exec" {
    command = "/usr/sbin/service nginx restart"
  }
}
