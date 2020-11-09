outputs "kubeconfig_file" {
  value = local_file.kubeconfig.filename
}

outputs "kubernetes_namespaces_consul" {
  value = kubernetes_namespace.consul.metadata[0].name
}
