
data "terraform_remote_state" "opnsense" {
  backend = "local"

  config = {
    path = "../opnsense-config/terraform.tfstate"
  }
}