##############################################################
# Module: NAT Gateway
#
# Creates:
#   aws_eip          — Elastic IP (static public IP per AZ)
#   aws_nat_gateway  — NAT Gateway per AZ (in PUBLIC subnet)
#
# What is NAT Gateway?
#   NAT = Network Address Translation
#   Problem: Private EC2 has no public IP, but needs to:
#     - Run: apt-get install nginx
#     - Pull: docker pull myimage
#     - Call: external APIs
#   NAT Gateway solution:
#     Private EC2 (10.0.10.5) → NAT GW (54.x.x.x) → Internet
#     Internet reply → NAT GW → Private EC2
#   The internet never sees the private IP, only the NAT GW Elastic IP.
#   Internet can NEVER initiate a connection to private EC2 — one-way only.
#
# ⚠️ Common mistake: NAT Gateway goes in PUBLIC subnet — NOT private.
#   It needs internet access itself to forward traffic out.
#
# Cost note: Each NAT GW costs ~$0.045/hr + data transfer.
#   For dev/test, use count = 1 to save cost.
#   For production, always one per AZ.
##############################################################

# Elastic IPs — static public IPs attached to NAT Gateways
# Private subnet traffic will appear to come FROM these IPs on the internet
resource "aws_eip" "nat" {
  count  = length(var.public_subnet_ids)
  domain = "vpc"   # Required for VPC-scoped EIPs (old: vpc = true)

  tags = { Name = "${var.project_name}-nat-eip-${count.index + 1}" }
}

# NAT Gateways — one per public subnet (= one per AZ)
resource "aws_nat_gateway" "main" {
  count = length(var.public_subnet_ids)

  allocation_id = aws_eip.nat[count.index].id          # attach Elastic IP
  subnet_id     = var.public_subnet_ids[count.index]   # place in PUBLIC subnet

  tags = {
    Name = "${var.project_name}-nat-gw-${count.index + 1}"
    AZ   = "az-${count.index + 1}"
  }

  # NAT Gateway takes ~60-90 seconds to become available
  # Terraform waits automatically — you don't need to do anything
}
