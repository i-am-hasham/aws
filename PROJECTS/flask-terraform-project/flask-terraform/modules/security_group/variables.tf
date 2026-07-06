variable "vpc_id" {
  description = "VPC ID to create security group in"
  type        = string
}

variable "my_ip" {
  description = "Your IP for SSH access"
  type        = string
}

variable "flask_port" {
  description = "Port Flask app runs on"
  type        = number
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
}
