##############################################################
# modules/ssm/main.tf
# Stores GitHub token in SSM Parameter Store
# CodeBuild reads it at runtime — never in code or logs
##############################################################

resource "aws_ssm_parameter" "github_token" {
  name        = "/cicd/github_token"
  description = "GitHub personal access token for CodePipeline source"
  type        = "SecureString"
  # SecureString = encrypted with KMS at rest
  # plaintext vs SecureString: never store tokens as plaintext
  value       = var.github_token

  tags = { Name = "cicd-github-token" }

  lifecycle {
    ignore_changes = [value]
    # After first apply, if you rotate the token manually in AWS Console,
    # Terraform will not overwrite it back to the tfvars value
  }
}

resource "aws_ssm_parameter" "ecr_repo_url" {
  name        = "/cicd/ecr_repo_url"
  description = "ECR repository URL - read by CodeBuild"
  type        = "String"
  value       = var.ecr_repo_url
  tags        = { Name = "cicd-ecr-repo-url" }
}

resource "aws_ssm_parameter" "container_name" {
  name        = "/cicd/container_name"
  description = "Docker container name - used by deploy scripts"
  type        = "String"
  value       = var.container_name
  tags        = { Name = "cicd-container-name" }
}
