variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "account_id" {
  description = "AWS account ID for unique S3 bucket naming"
  type        = string
}

variable "codepipeline_role_arn" {
  description = "IAM role ARN for CodePipeline"
  type        = string
}

variable "github_owner" {
  description = "GitHub username or organization"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch to watch"
  type        = string
}

variable "codestar_connection_arn" {
  description = "CodeStar connection ARN for GitHub v2 - created in root main.tf"
  type        = string
}

variable "codebuild_project_name" {
  description = "CodeBuild project name"
  type        = string
}

variable "codedeploy_app_name" {
  description = "CodeDeploy application name"
  type        = string
}

variable "codedeploy_deployment_group" {
  description = "CodeDeploy deployment group name"
  type        = string
}