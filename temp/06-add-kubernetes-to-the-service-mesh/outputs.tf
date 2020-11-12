output "kubeconfig_file" {
  value = local_file.kubeconfig.filename
}

output "kubernetes_namespaces_consul" {
  value = kubernetes_namespace.consul.metadata[0].name
}
