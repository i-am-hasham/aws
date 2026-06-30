output "vpc_id" {
  description = "VPC ID — needed by all other modules"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "igw_id" {
  description = "IGW ID — needed by public route table"
  value       = aws_internet_gateway.main.id
}