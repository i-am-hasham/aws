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
  default     = "hasham-cicd"
}

# ── GitHub ────────────────────────────────────────────────────
variable "github_owner" {
  description = "GitHub username or organization name"
  type        = string
  default     = "i-am-hasham"
}

variable "github_repo" {
  description = "GitHub repository name (must exist)"
  type        = string
  default     = "flask-cicd-app"
}

variable "github_branch" {
  description = "Branch to watch for changes"
  type        = string
  default     = "main"
}

variable "github_token" {
  description = "GitHub token - only used for SSM parameter. Real value already in SSM via CLI."
  type        = string
  sensitive   = true
  default     = "placeholder"
}

# ── ECR ───────────────────────────────────────────────────────
variable "ecr_repo_name" {
  description = "ECR repository name for Docker images"
  type        = string
  default     = "flask-cicd-app"
}

# ── EC2 ───────────────────────────────────────────────────────
variable "instance_type" {
  description = "EC2 instance type for the deployment target"
  type        = string
  default     = "t2.micro"
}

variable "ami" {
  description = "Ubuntu 22.04 LTS AMI ID in us-east-1"
  type        = string
  default     = "ami-0c7217cdde317cfec"
}

variable "key_pair_name" {
  description = "Existing AWS key pair for SSH to EC2"
  type        = string
  default     = "hasham-key"
}

variable "my_ip" {
  description = "Your IP for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}

# ── App ───────────────────────────────────────────────────────
variable "app_port" {
  description = "Port the Flask app runs on inside Docker container"
  type        = number
  default     = 5000
}

variable "container_name" {
  description = "Docker container name on EC2"
  type        = string
  default     = "flask-cicd-app"
}