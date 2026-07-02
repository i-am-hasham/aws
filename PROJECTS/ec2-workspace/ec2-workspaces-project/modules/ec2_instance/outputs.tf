output "instance_ids" {
  description = "IDs of all created EC2 instances"
  value       = aws_instance.app[*].id
}

output "private_ips" {
  description = "Private IPs of all created EC2 instances"
  value       = aws_instance.app[*].private_ip
}
