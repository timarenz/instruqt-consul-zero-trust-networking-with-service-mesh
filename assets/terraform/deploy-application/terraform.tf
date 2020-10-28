terraform {
  required_providers {
    consul = {
      source  = "hashicorp/consul"
      version = "= 2.10.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "= 3.44.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "= 2.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "= 3.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "= 3.0.0"
    }
  }
}
