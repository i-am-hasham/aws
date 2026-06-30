##############################################################
# variables.tf — All input variables for the project
#
# WHY separate variables file?
#   Keeps main.tf clean. Anyone reading variables.tf immediately
#   understands ALL the knobs they can turn — region, CIDRs,
#   instance type, key name — without reading any resource code.
##############################################################

# ── General ───────────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region where all resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for naming all resources (e.g. hasham-vpc-subnet-1)"
  type        = string
  default     = "hasham-vpc"
}

variable "environment" {
  description = "Environment tag (production / staging / dev)"
  type        = string
  default     = "production"
}

# ── VPC & Networking ──────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR for the entire VPC. /16 = 65,536 available IPs"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets — one per AZ. /24 = 256 IPs each"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets — one per AZ"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
  # Using .10 and .20 to visually separate from public (.1 and .2)
}

variable "availability_zones" {
  description = "AZs to spread resources across — must match subnet list count"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ── Bastion Host ──────────────────────────────────────────────
variable "bastion_instance_type" {
  description = "EC2 instance type for bastion (t2.micro = free tier)"
  type        = string
  default     = "t2.micro"
}

variable "bastion_ami" {
  description = "AMI ID — Ubuntu 22.04 LTS in us-east-1"
  type        = string
  default     = "ami-0c7217cdde317cfec"
}

variable "key_pair_name" {
  description = "Existing AWS key pair name for SSH to bastion"
  type        = string
  default     = "hasham-key"
  # Create with: aws ec2 create-key-pair --key-name hasham-key \
  #   --query 'KeyMaterial' --output text > ~/.ssh/hasham-key.pem
}

variable "my_ip" {
  description = "YOUR public IP in CIDR notation for SSH to bastion. Find at checkip.amazonaws.com"
  type        = string
  default     = "0.0.0.0/0"
  # IMPORTANT: Replace 0.0.0.0/0 with your actual IP: "182.191.45.12/32"
  # 0.0.0.0/0 means anyone can SSH — not safe for production
}
