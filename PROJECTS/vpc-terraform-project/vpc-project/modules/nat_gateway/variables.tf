variable "public_subnet_ids" {
  description = "Public subnet IDs — NAT GW is placed here"
  type        = list(string)
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
}