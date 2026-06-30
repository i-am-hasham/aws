output "nat_gateway_ids" {
  description = "NAT Gateway IDs — used by private route tables"
  value       = aws_nat_gateway.main[*].id
}

output "nat_eip_public_ips" {
  description = "Elastic IPs of NAT GWs — private traffic exits here"
  value       = aws_eip.nat[*].public_ip
}