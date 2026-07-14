output "github_token_arn"   { value = aws_ssm_parameter.github_token.arn }
output "ecr_repo_url_arn"   { value = aws_ssm_parameter.ecr_repo_url.arn }
output "github_token_name"  { value = aws_ssm_parameter.github_token.name }
