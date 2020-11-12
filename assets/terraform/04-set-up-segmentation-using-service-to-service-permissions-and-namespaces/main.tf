data "terraform_remote_state" "base" {
  backend = "local"

  config = {
    path = "../01-introducing-hashicups/terraform.tfstate"
  }
}

