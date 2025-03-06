terraform {
  backend "s3" {
    bucket         = "tf-state-tfawskronoss-wkspace-1ff1a911"
    key            = "tfawskronoss-wkspace/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-tfawskronoss-wkspace-1ff1a911"
  }
}
