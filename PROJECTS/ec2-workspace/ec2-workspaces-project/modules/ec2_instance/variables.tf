variable "ami" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (already resolved by lookup() in root main.tf)"
  type        = string
}

variable "instance_count" {
  description = "Number of EC2 instances to create (already resolved by lookup())"
  type        = number
}

variable "subnet_id" {
  description = "Subnet ID to launch instances in (reused from VPC project)"
  type        = string
}

variable "sg_id" {
  description = "Security Group ID to attach (reused from VPC project)"
  type        = string
}

variable "key_pair_name" {
  description = "AWS key pair name for SSH"
  type        = string
}

variable "project_name" {
  description = "Project name prefix for naming"
  type        = string
}

variable "environment" {
  description = "Current workspace name (dev/stage/prod) - used in tags"
  type        = string
}
