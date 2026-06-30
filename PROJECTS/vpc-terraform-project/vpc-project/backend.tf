##############################################################
# backend.tf — Remote State Configuration
#
# STEP 2: After backend-setup is applied, uncomment this and run:
#   terraform init
#   (Terraform will ask: "Copy existing state?" → type yes)
#
# WHY remote backend?
#   Local state = only you can collaborate, risk of losing it
#   Remote S3 state = entire team shares same state file
#   DynamoDB locking = nobody can corrupt state with concurrent apply
##############################################################

terraform {
  backend "s3" {
    bucket         = "hasham-vpc-project-tfstate"
    key            = "vpc-project/terraform.tfstate"  # path inside the bucket
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
