### backend.tf ###
terraform {
  backend "s3" {
    bucket         = "tf-state-945a30510"
    key            = "terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-tf-kronos-wkp-dr" # This will be replaced dynamically by bootstrap.sh
  }
}
