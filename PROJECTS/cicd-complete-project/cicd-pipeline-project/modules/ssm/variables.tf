variable "github_token" {
  description = "GitHub PAT"
  type        = string
  sensitive   = true
}

variable "ecr_repo_url" {
  description = "ECR repo URL"
  type        = string
}

variable "container_name" {
  description = "Docker container name"
  type        = string
}
