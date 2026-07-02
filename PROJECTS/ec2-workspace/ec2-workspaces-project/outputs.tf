##############################################################
# outputs.tf
##############################################################

output "current_workspace" {
  description = "Which workspace this apply ran in"
  value       = terraform.workspace
}

output "instance_type_used" {
  description = "Instance type lookup() resolved for this workspace"
  value       = lookup(var.instance_type, terraform.workspace, "t2.micro")
}

output "instance_count_used" {
  description = "Instance count lookup() resolved for this workspace"
  value       = lookup(var.instance_count, terraform.workspace, 1)
}

output "instance_ids" {
  description = "EC2 instance IDs created in this workspace"
  value       = module.ec2_instance.instance_ids
}

output "instance_private_ips" {
  description = "Private IPs of EC2 instances created in this workspace"
  value       = module.ec2_instance.private_ips
}

output "reused_vpc_id" {
  description = "VPC ID reused from the VPC project (proof of remote state reuse)"
  value       = data.terraform_remote_state.vpc.outputs.vpc_id
}

output "reused_subnet_id" {
  description = "Subnet ID reused from the VPC project"
  value       = data.terraform_remote_state.vpc.outputs.private_subnet_ids[0]
}

output "summary" {
  description = "Human-readable summary"
  value = <<-EOT

    ╔══════════════════════════════════════════════════╗
    ║   WORKSPACE: ${terraform.workspace}
    ╠══════════════════════════════════════════════════╣
    ║   Instance Type  : ${lookup(var.instance_type, terraform.workspace, "t2.micro")}
    ║   Instance Count : ${lookup(var.instance_count, terraform.workspace, 1)}
    ║   Reused VPC     : ${data.terraform_remote_state.vpc.outputs.vpc_id}
    ║   Reused Subnet  : ${data.terraform_remote_state.vpc.outputs.private_subnet_ids[0]}
    ╚══════════════════════════════════════════════════╝

  EOT
}
