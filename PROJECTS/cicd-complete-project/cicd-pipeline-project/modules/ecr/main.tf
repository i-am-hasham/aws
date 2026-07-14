##############################################################
# modules/ecr/main.tf
# Creates: ECR repository for Docker images
##############################################################

resource "aws_ecr_repository" "app" {
  name                 = var.repo_name
  image_tag_mutability = "MUTABLE"
  # MUTABLE = can overwrite "latest" tag
  # IMMUTABLE = each tag can only be pushed once (safer in production)

  image_scanning_configuration {
    scan_on_push = true
    # Automatically scans for CVEs every time image is pushed
  }

  tags = { Name = var.repo_name }
}

# Lifecycle policy — auto-delete old images to save storage cost
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
