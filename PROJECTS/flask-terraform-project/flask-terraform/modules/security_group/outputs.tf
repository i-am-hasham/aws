output "sg_id" {
  description = "Flask EC2 security group ID"
  value       = aws_security_group.flask.id
}
