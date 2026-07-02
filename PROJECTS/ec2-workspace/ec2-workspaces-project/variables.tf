##############################################################
# variables.tf
##############################################################

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
  default     = "hasham-ec2-ws"
}

variable "ami" {
  description = "AMI ID used for the EC2 instance in every workspace"
  type        = string
  default     = "ami-0c7217cdde317cfec"  # Ubuntu 22.04 LTS us-east-1
}

# ── The core of this project ──────────────────────────────────
# A MAP where each key is a workspace name and the value is the
# instance type to use in that workspace. lookup() reads the
# current workspace name and picks the matching value.
variable "instance_type" {
  description = "Map of workspace name -> EC2 instance type"
  type        = map(string)

  default = {
    dev   = "t2.micro"
    stage = "t2.medium"
    prod  = "t2.xlarge"
  }
}

# Map of workspace name -> how many instances to launch
# dev needs 1 for testing, prod needs more for availability
variable "instance_count" {
  description = "Map of workspace name -> number of EC2 instances"
  type        = map(number)

  default = {
    dev   = 1
    stage = 1
    prod  = 2
  }
}

variable "key_pair_name" {
  description = "AWS key pair name for SSH access"
  type        = string
  default     = "hasham-key"
}
