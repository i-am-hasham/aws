variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "igw_id" {
  description = "Internet Gateway ID"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "AZs to place subnets in"
  type        = list(string)
}

variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
}

variable "nat_gateway_ids" {
  description = "NAT GW IDs for private route tables"
  type        = list(string)
}