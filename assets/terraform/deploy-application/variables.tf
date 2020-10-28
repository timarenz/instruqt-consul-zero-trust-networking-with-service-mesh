variable "gcp_project" {
  type = string
}

variable "gcp_region" {
  type    = string
  default = "europe-west4"
}

variable "environment_name" {
  type    = string
  default = "consul-on-prem"
}

variable "owner_name" {
  type    = string
  default = "hashicorp"
}

variable "ssh_username" {
  type    = string
  default = "jeff"
}

variable "consul_primary_dc" {
  default = "on-prem"
}
