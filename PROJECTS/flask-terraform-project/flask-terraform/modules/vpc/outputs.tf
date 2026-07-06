output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID - Flask EC2 is placed here"
  value       = aws_subnet.public.id
}
