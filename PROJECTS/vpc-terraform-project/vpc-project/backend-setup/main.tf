##############################################################
# STEP 1 — Run this FIRST, before the main project
# Creates the S3 bucket + DynamoDB table for remote state
#
# Commands:
#   cd backend-setup/
#   terraform init
#   terraform apply
##############################################################

provider "aws" {
  region = "us-east-1"
}

# ── S3 Bucket ─────────────────────────────────────────────────
resource "aws_s3_bucket" "terraform_state" {
  bucket = "hasham-vpc-project-tfstate"

  lifecycle {
    prevent_destroy = true   # Safety: prevents accidental deletion
  }

  tags = {
    Name      = "Terraform State Bucket"
    Project   = "vpc-network-setup"
    ManagedBy = "Terraform"
  }
}

# Versioning — keeps every version of tfstate, so you can roll back
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration { status = "Enabled" }
}

# Server-side encryption — state file often contains sensitive values
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

# Block ALL public access — tfstate must NEVER be public
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── DynamoDB Table for State Locking ─────────────────────────
# Prevents two engineers from running terraform apply at the same time
# Terraform writes a lock record here before apply, removes it after
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "hasham-vpc-project-tflock"
  billing_mode = "PAY_PER_REQUEST"   # Pay only when used — near zero cost
  hash_key     = "LockID"            # Required field name for Terraform

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "Terraform Lock Table"
    Project   = "vpc-network-setup"
    ManagedBy = "Terraform"
  }
}

output "s3_bucket_name"     { value = aws_s3_bucket.terraform_state.bucket }
output "dynamodb_table_name" { value = aws_dynamodb_table.terraform_locks.name }
