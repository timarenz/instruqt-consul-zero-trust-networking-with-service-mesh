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

resource "kubernetes_secret" "consul" {
  metadata {
    name      = "consul"
    namespace = kubernetes_namespace.consul.metadata[0].name
  }

  data = {
    replicationToken = data.consul_acl_token_secret_id.replication.secret_id
  }
}

resource "kubernetes_namespace" "consul" {
  metadata {
    name = "consul"
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
    name  = "global.enableConsulNamespaces"
    value = true
  }

  set {
    name  = "global.acls.manageSystemACLs"
    value = true
  }

  set {
    name  = "global.acls.replicationToken.secretName"
    value = kubernetes_secret.consul.metadata[0].name
  }

  set {
    name  = "global.acls.replicationToken.secretKey"
    value = "replicationToken"
  }

  set {
    name  = "global.federation.enabled"
    value = true
  }


  # values = [<<EOF
  # server:
  #   extraConfig: |
  #     { "log_level"   : "TRACE" }
  # client:
  #   extraConfig: |
  #     { "log_level"   : "TRACE" }
  # EOF
  # ]
}


