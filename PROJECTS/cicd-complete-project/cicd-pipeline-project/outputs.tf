output "ecr_repository_url" {
  description = "ECR URL - used in buildspec.yml"
  value       = module.ecr.repository_url
}

output "ec2_public_ip" {
  description = "EC2 public IP - access the app here after first deploy"
  value       = module.ec2.public_ip
}

output "app_url" {
  description = "Flask app URL - accessible after first pipeline run"
  value       = "http://${module.ec2.public_ip}"
}

output "pipeline_name" {
  description = "CodePipeline name"
  value       = module.codepipeline.pipeline_name
}

output "artifact_bucket" {
  description = "S3 bucket storing pipeline artifacts"
  value       = module.codepipeline.artifact_bucket_name
}

output "codebuild_project" {
  description = "CodeBuild project name"
  value       = module.codebuild.project_name
}

output "codedeploy_app" {
  description = "CodeDeploy application name"
  value       = module.codedeploy.app_name
}

output "ssh_command" {
  description = "SSH to EC2"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${module.ec2.public_ip}"
}

output "trigger_pipeline_command" {
  description = "Manually trigger pipeline via CLI"
  value       = "aws codepipeline start-pipeline-execution --name ${module.codepipeline.pipeline_name} --region ${var.aws_region}"
}

output "summary" {
  value = <<-EOT

    ╔══════════════════════════════════════════════════════════╗
    ║        AWS CI/CD PIPELINE — DEPLOYED                     ║
    ╠══════════════════════════════════════════════════════════╣
    ║  Pipeline   : ${module.codepipeline.pipeline_name}
    ║  ECR Repo   : ${module.ecr.repository_url}
    ║  EC2 IP     : ${module.ec2.public_ip}
    ║  App URL    : http://${module.ec2.public_ip}
    ╠══════════════════════════════════════════════════════════╣
    ║  NEXT STEPS:
    ║  1. Push code to GitHub → pipeline triggers automatically
    ║  2. Watch: AWS Console → CodePipeline
    ║  3. After deploy: open http://${module.ec2.public_ip}
    ╚══════════════════════════════════════════════════════════╝

  EOT
}
