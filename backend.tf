### backend.tf ###
terraform {
  backend "s3" {
    bucket  = "tf-state-945a3051"
    key     = "terraform.tfstate"
    region  = "eu-west-1"
    encrypt = true
  }
}
