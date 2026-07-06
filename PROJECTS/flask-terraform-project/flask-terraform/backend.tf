##############################################################
# backend.tf
#
# Reuses the same S3 bucket from backend-setup (still alive
# because of prevent_destroy). Different key = separate state
# from every other project.
##############################################################

terraform {
  backend "s3" {
    bucket         = "hasham-vpc-project-tfstate"
    key            = "flask-terraform-project/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "hasham-vpc-project-tflock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.5.0"
}
