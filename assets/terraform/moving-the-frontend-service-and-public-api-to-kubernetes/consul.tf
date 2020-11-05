provider "consul" {
  address    = data.terraform_remote_state.base.outputs.consul_http_addr
  token      = data.terraform_remote_state.base.outputs.consul_master_token
  datacenter = data.terraform_remote_state.base.outputs.consul_primary_dc
}

resource "consul_acl_policy" "replication" {
  name  = "replication"
  rules = <<-RULE
    acl = "write"

    operator = "write"

    agent_prefix "" {
      policy = "read"
    }

    node_prefix "" {
      policy = "write"
    }

    namespace_prefix "" {

      service_prefix "" {
        policy = "read"
        intentions = "read"
      }

    }
    RULE
}

resource "consul_acl_token" "replication" {
  policies = [consul_acl_policy.replication.name]
}

data "consul_acl_token_secret_id" "replication" {
  accessor_id = consul_acl_token.replication.id
}

resource "kubernetes_namespace" "consul" {
  metadata {
    name = "consul"
  }
}

resource "kubernetes_secret" "consul_federation" {
  metadata {
    name      = "consul-federation"
    namespace = kubernetes_namespace.consul.metadata[0].name
  }

  data = {
    gossipEncryptionKey = data.terraform_remote_state.base.outputs.consul_gossip_encryption_key
    caCert              = data.terraform_remote_state.base.outputs.ca_cert
    caKey               = data.terraform_remote_state.base.outputs.ca_private_key
    replicationToken    = data.consul_acl_token_secret_id.replication.secret_id
  }
}

provider "helm" {
  kubernetes {
    host                   = module.k8s.endpoint
    cluster_ca_certificate = module.k8s.cluster_ca_certificate
    token                  = data.google_client_config.client.access_token

    load_config_file = false
  }
}

resource "helm_release" "consul" {
  depends_on = [module.k8s]
  provider   = helm

  name       = "consul"
  chart      = "consul"
  repository = "https://helm.releases.hashicorp.com"
  namespace  = kubernetes_namespace.consul.metadata[0].name
  version    = "0.25.0"

  set {
    name  = "global.name"
    value = "consul"
  }

  set {
    name  = "global.image"
    value = "hashicorp/consul-enterprise:1.8.5-ent"
  }

  set {
    name  = "global.imageEnvoy"
    value = "envoyproxy/envoy-alpine:v1.14.4"
  }

  set {
    name  = "global.datacenter"
    value = "cloud"
  }

  set {
    name  = "global.gossipEncryption.secretName"
    value = kubernetes_secret.consul_federation.metadata[0].name
  }

  set {
    name  = "global.gossipEncryption.secretKey"
    value = "gossipEncryptionKey"
  }

  set {
    name  = "global.tls.enabled"
    value = true
  }

  set {
    name  = "global.tls.httpsOnly"
    value = false
  }

  set {
    name  = "global.tls.caCert.secretName"
    value = kubernetes_secret.consul_federation.metadata[0].name
  }

  set {
    name  = "global.tls.caCert.secretKey"
    value = "caCert"
  }

  set {
    name  = "global.tls.caKey.secretName"
    value = kubernetes_secret.consul_federation.metadata[0].name
  }

  set {
    name  = "global.tls.caKey.secretKey"
    value = "caKey"
  }

  set {
    name  = "global.enableConsulNamespaces"
    value = true
  }

  set {
    name  = "global.acls.manageSystemACLs"
    value = true
  }

  set {
    name  = "global.acls.replicationToken.secretName"
    value = kubernetes_secret.consul_federation.metadata[0].name
  }

  set {
    name  = "global.acls.replicationToken.secretKey"
    value = "replicationToken"
  }

  set {
    name  = "global.federation.enabled"
    value = true
  }

  set {
    name  = "syncCatalog.enabled"
    value = true
  }

  set {
    name  = "syncCatalog.default"
    value = false
  }

  set {
    name  = "syncCatalog.consulNamespaces.mirroringK8S"
    value = true
  }

  set {
    name  = "syncCatalog.addK8SNamespaceSuffix"
    value = false
  }

  set {
    name  = "connectInject.enabled"
    value = true
  }

  set {
    name  = "connectInject.centralConfig.enabled"
    value = true
  }

  set {
    name  = "connectInject.consulNamespaces.mirroringK8S"
    value = true
  }

  set {
    name  = "meshGateway.enabled"
    value = true
  }

  values = [<<EOF
  server:
    extraConfig: |
      {
        "log_level": "TRACE",
        "primary_datacenter": "on-prem",
        "primary_gateways": ["${module.mesh_gateway.public_ip}"]
      }
  EOF
  ]
}


