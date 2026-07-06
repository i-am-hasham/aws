##############################################################
# variables.tf
##############################################################

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "hasham-flask"
}

# ── Networking ────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR - Flask EC2 lives here"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "AZ to launch the subnet and EC2 in"
  type        = string
  default     = "us-east-1a"
}

# ── EC2 ───────────────────────────────────────────────────────
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ami" {
  description = "Ubuntu 22.04 LTS in us-east-1"
  type        = string
  default     = "ami-0c7217cdde317cfec"
}

variable "key_pair_name" {
  description = "Existing AWS key pair name for SSH"
  type        = string
  default     = "hasham-key"
}

variable "my_ip" {
  description = "Your public IP in CIDR for SSH access. Find at checkip.amazonaws.com"
  type        = string
  default     = "0.0.0.0/0"
  # Replace with your real IP: "182.191.45.12/32"
}

variable "flask_port" {
  description = "Port Flask app runs on"
  type        = number
  default     = 5000
}

variable "ssh_private_key_path" {
  description = "Local path to your .pem private key file for provisioners"
  type        = string
  default     = "~/.ssh/hasham-key.pem"
}
