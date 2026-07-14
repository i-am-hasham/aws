output "pipeline_name" {
  description = "CodePipeline name"
  value       = aws_codepipeline.app.name
}

output "artifact_bucket_name" {
  description = "S3 artifact bucket name"
  value       = aws_s3_bucket.artifacts.bucket
}

output "artifact_bucket_arn" {
  description = "S3 artifact bucket ARN - used by IAM module to scope permissions"
  value       = aws_s3_bucket.artifacts.arn
}