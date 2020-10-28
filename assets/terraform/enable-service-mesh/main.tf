data "terraform_remote_state" "base" {
  backend = "local"

  config = {
    path = "../deploy-application/terraform.tfstate"
  }
}
