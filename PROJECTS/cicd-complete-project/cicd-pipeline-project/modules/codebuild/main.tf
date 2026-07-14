##############################################################
# modules/codebuild/main.tf
# Creates: CodeBuild project that runs buildspec.yml
##############################################################

resource "aws_codebuild_project" "app" {
  name          = "${var.project_name}-build"
  description   = "Builds Docker image and pushes to ECR"
  service_role  = var.codebuild_role_arn
  build_timeout = 20   # minutes

  # Source: CodePipeline passes the GitHub code here
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
    # Reads buildspec.yml from root of the repository
  }

  # Artifacts: built files passed to next pipeline stage (CodeDeploy)
  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    # privileged_mode required for running Docker commands inside CodeBuild
    # Without this: docker build commands fail
    privileged_mode = true

    # Environment variables available in buildspec.yml
    environment_variable {
      name  = "ECR_REPO_NAME"
      value = var.ecr_repo_name
    }

    environment_variable {
      name  = "CONTAINER_NAME"
      value = var.container_name
    }

    environment_variable {
      name  = "APP_PORT"
      value = tostring(var.app_port)
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
  }

  # CloudWatch Logs for build output
  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_name}"
      stream_name = "build-logs"
    }
  }

  tags = { Name = "${var.project_name}-build" }
}

# CloudWatch Log Group for CodeBuild logs
resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/${var.project_name}"
  retention_in_days = 14
  tags              = { Name = "${var.project_name}-codebuild-logs" }
}
