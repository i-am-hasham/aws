What this code does
This project creates an EC2 instance and two S3 buckets, and then configures one of those S3 buckets as the remote backend to store the Terraform state file instead of keeping it locally.

Problem with this code — chicken and egg problem
There is a fundamental issue here that you must understand.
You need S3 bucket to exist → to store state file
But Terraform creates S3 bucket → using state file
You cannot use the same Terraform run to both create the S3 bucket and use it as a backend. The bucket must exist before you configure it as a backend.

Correct way to set this up
Step 1 — Create S3 bucket first without backend config
Comment out the backend block and apply:
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket = "hasham-s3-demo-xyz"
}

# backend block commented out for now
terraform init
terraform apply
S3 bucket now exists on AWS.
Step 2 — Now add backend config and reinitialize
terraform {
  backend "s3" {
    bucket = "hasham-s3-demo-xyz"
    key    = "hash/terraform.tfstate"
    region = "us-east-1"
  }
}
terraform init
Terraform will ask:
Do you want to copy existing state to the new backend?
Enter a value: yes
State file is now moved from local to S3.

Explaining every part of the backend block
terraform {
  backend "s3" {
    bucket = "hasham-s3-demo-xyz"
    key    = "hash/terraform.tfstate"
    region = "us-east-1"
  }
}
backend "s3" — tells Terraform to use S3 as the remote backend instead of local file system.
bucket — the name of the S3 bucket where state file will be stored. Must already exist.
key — the path inside the S3 bucket where the state file will be saved. Think of it like a folder path.
S3 bucket: hasham-s3-demo-xyz
    └── hash/
        └── terraform.tfstate   ← state file lives here
You can use any path you want. Using a meaningful path is useful when multiple projects share the same bucket:
project-1/dev/terraform.tfstate
project-1/prod/terraform.tfstate
project-2/dev/terraform.tfstate
region — the AWS region where your S3 bucket lives.

Why DynamoDB is commented out
The DynamoDB table is for state locking — preventing two people from running terraform apply at the same time which could corrupt the state.
Without DynamoDB you have remote state storage but no locking. Two people can still run apply simultaneously and corrupt the state.
To enable locking uncomment the DynamoDB resource and add it to backend:
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
terraform {
  backend "s3" {
    bucket         = "hasham-s3-demo-xyz"
    key            = "hash/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"    ← add this
    encrypt        = true                ← add this for security
  }
}

What happens after backend is configured
Before backend:
terraform apply
        │
        ▼
terraform.tfstate saved on your laptop

After backend:
terraform apply
        │
        ▼
terraform.tfstate saved in S3 bucket
        │
        ▼
Anyone on your team runs terraform
        │
        ▼
They read same state from S3
Everyone is in sync

Full picture of what this project creates
AWS
├── EC2 instance (t2.micro, Ubuntu)
├── S3 bucket: hasham-s3-demo-xyz    ← also used as backend
└── S3 bucket: hasham12-s3-demo-xyz

S3: hasham-s3-demo-xyz
└── hash/
    └── terraform.tfstate            ← state stored here

One line summary
Remote backend moves your state file from your local machine to S3 so your entire team shares the same state. The key is where inside the bucket the file lives, and DynamoDB adds locking to prevent simultaneous applies from corrupting it.