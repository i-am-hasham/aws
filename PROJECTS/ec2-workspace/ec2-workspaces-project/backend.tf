##############################################################
# backend.tf — Remote state for THIS project
#
# Reuses the SAME S3 bucket and DynamoDB table created in the
# VPC project's backend-setup/. Just a different "key" (path)
# inside the bucket so the two projects don't overwrite
# each other's state.
#
# IMPORTANT: This requires the VPC project's backend-setup/
# to have been applied at least once (S3 bucket + DynamoDB
# table must exist). If you destroyed everything including
# backend-setup, re-apply it first:
#   cd ../vpc-terraform-project/vpc-project/backend-setup/
#   terraform apply
##############################################################

terraform {
  backend "s3" {
    bucket         = "hasham-vpc-project-tfstate"
    key            = "ec2-workspaces-project/terraform.tfstate"  # different key = different project
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
