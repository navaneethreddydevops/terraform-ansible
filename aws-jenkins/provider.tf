terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  backend "s3" {
    region = "us-east-1"
    bucket = "terraform-state-035612810169-us-east-1"
    key    = "app-name/state.json"

  }
}

# Configure the AWS Provider
provider "aws" {
  region                  = var.region
  shared_credentials_file = var.shared_credentials_file
  profile                 = var.profile
}