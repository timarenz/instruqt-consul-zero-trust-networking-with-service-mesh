output "consul_ingress_gateway_lb_ip" {
  value = data.kubernetes_service.consul_ingress_gateway.load_balancer_ingress[0].ip
}
