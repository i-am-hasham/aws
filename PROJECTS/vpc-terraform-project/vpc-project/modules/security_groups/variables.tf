variable "vpc_id" {
  description = "VPC to create security groups in"
  type        = string
}

variable "my_ip" {
  description = "Your IP in CIDR (e.g. 1.2.3.4/32) for SSH to bastion"
  type        = string
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
}