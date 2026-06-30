##############################################################
# outputs.tf — Values exposed after terraform apply
#
# WHY outputs matter?
#   1. You see key info immediately after apply (IPs, IDs)
#   2. Other Terraform projects can read these via remote state:
#      data "terraform_remote_state" "vpc" { ... }
#      subnet_id = data.terraform_remote_state.vpc.outputs.private_subnet_ids[0]
##############################################################

output "vpc_id" {
  description = "VPC ID — reference this in other projects"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs (use for ALB, Bastion, NAT GW)"
  value       = module.subnets.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs (use for EC2 app servers, RDS)"
  value       = module.subnets.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs — one per AZ"
  value       = module.nat_gateway.nat_gateway_ids
}

output "nat_eip_public_ips" {
  description = "Elastic IPs of NAT Gateways — private subnet traffic exits from here"
  value       = module.nat_gateway.nat_eip_public_ips
}

output "bastion_public_ip" {
  description = "Bastion host public IP — SSH to this"
  value       = module.bastion.bastion_public_ip
}

output "bastion_ssh_command" {
  description = "Ready-to-run SSH command for bastion access"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${module.bastion.bastion_public_ip}"
}

output "bastion_sg_id" {
  description = "Bastion SG ID — reference as source in private instance SGs"
  value       = module.security_groups.bastion_sg_id
}

output "private_instance_sg_id" {
  description = "Private instance SG ID — attach to app servers and RDS"
  value       = module.security_groups.private_instance_sg_id
}

output "alb_sg_id" {
  description = "ALB SG ID — attach to any load balancer in this VPC"
  value       = module.security_groups.alb_sg_id
}

output "summary" {
  description = "Human-readable summary of what was built"
  value = <<-EOT

    ╔══════════════════════════════════════════════════╗
    ║       AWS VPC NETWORK SETUP — COMPLETE           ║
    ╠══════════════════════════════════════════════════╣
    ║  VPC ID         : ${module.vpc.vpc_id}
    ║  VPC CIDR       : ${module.vpc.vpc_cidr}
    ║  Public Subnets : ${join(", ", module.subnets.public_subnet_ids)}
    ║  Private Subnets: ${join(", ", module.subnets.private_subnet_ids)}
    ║  Bastion IP     : ${module.bastion.bastion_public_ip}
    ║  SSH Command    : ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${module.bastion.bastion_public_ip}
    ╚══════════════════════════════════════════════════╝

  EOT
}
