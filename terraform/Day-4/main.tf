provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "hasham" {
  instance_type = "t2.micro"
  ami = "ami-091138d0f0d41ff90" # change this
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket = "hasham-s3-demo-xyz" # change this
}
resource "aws_s3_bucket" "s3_bucket_2" {
  bucket = "hasham12-s3-demo-xyz" # change this
}

/*resource "aws_dynamodb_table" "terraform_lock" {
  name           = "terraform-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
*/