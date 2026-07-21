variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "hasham-3tier"
}

variable "environment" {
  type    = string
  default = "production"
}

# ── Networking ────────────────────────────────────────────────
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "private_db_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.100.0/24", "10.0.200.0/24"]
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

# ── EC2 / ASG ─────────────────────────────────────────────────
variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "ami" {
  type    = string
  default = "ami-0c7217cdde317cfec"
}

variable "key_pair_name" {
  type    = string
  default = "hasham-key"
}

variable "asg_min_size" {
  type    = number
  default = 2
}

variable "asg_max_size" {
  type    = number
  default = 4
}

variable "asg_desired_size" {
  type    = number
  default = 2
}

# ── RDS ───────────────────────────────────────────────────────
variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "admin"
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = "ChangeMe123!"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_engine_version" {
  type    = string
  default = "8.0"
}

# ── Monitoring ────────────────────────────────────────────────
variable "alert_email" {
  type    = string
  default = "hasham@example.com"
}

variable "my_ip" {
  type    = string
  default = "0.0.0.0/0"
}