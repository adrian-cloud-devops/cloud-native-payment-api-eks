terraform {
  backend "s3" {
    bucket         = "payment-api-tfstate-adrian-cloud-devops"
    key            = "infrastructure/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "payment-api-tflock"
    encrypt        = true
  }
}