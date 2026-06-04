terraform {
  backend "s3" {
    bucket         = "hasham-s3-demo-xyz" # change this
    key            = "hash/terraform.tfstate"
    region         = "us-east-1"
  }
}
