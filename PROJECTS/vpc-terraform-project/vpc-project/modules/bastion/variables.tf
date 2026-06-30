variable "public_subnet_id" {
  description = "Public subnet ID for bastion placement"
  type        = string
}

variable "bastion_sg_id" {
  description = "Security group ID for bastion"
  type        = string
}

variable "bastion_instance_type" {
  description = "EC2 instance type (t2.micro = free)"
  type        = string
  default     = "t2.micro"
}

variable "bastion_ami" {
  description = "AMI ID for bastion OS"
  type        = string
}

variable "key_pair_name" {
  description = "AWS key pair name for SSH"
  type        = string
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
}