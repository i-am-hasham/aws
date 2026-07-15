terraform {
  backend "s3" {
    bucket         = "hasham-vpc-project-tfstate"
    key            = "three-tier-project/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "hasham-vpc-project-tflock"
  }
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  required_version = ">= 1.5.0"
}
