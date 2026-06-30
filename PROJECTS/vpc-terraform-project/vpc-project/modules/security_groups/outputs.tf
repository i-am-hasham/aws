output "bastion_sg_id" {
  description = "Bastion SG ID"
  value       = aws_security_group.bastion.id
}

output "private_instance_sg_id" {
  description = "Private instance SG ID"
  value       = aws_security_group.private_instances.id
}

output "alb_sg_id" {
  description = "ALB SG ID"
  value       = aws_security_group.alb.id
}