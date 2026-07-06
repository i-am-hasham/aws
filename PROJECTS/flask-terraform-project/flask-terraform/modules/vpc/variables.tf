variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
}

variable "availability_zone" {
  description = "AZ for the public subnet"
  type        = string
}

variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
}
