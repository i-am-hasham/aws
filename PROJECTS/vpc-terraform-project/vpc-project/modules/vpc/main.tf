##############################################################
# Module: VPC
#
# Creates:
#   aws_vpc            — the isolated network itself
#   aws_internet_gateway — the door between VPC and internet
#
# Why enable_dns_hostnames?
#   Required for EKS, ECS, and private DNS (e.g. RDS endpoint
#   resolves to a private IP inside the VPC instead of public)
##############################################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true   # EC2s get DNS names like ec2-x-x-x-x.compute.amazonaws.com
  enable_dns_support   = true   # Required for private DNS resolution inside VPC

  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  # WHY: Without IGW, NO traffic can enter or leave the VPC — not even
  # resources with public IPs. IGW is the mandatory bridge to the internet.
  # One IGW per VPC (AWS limit).

  tags = { Name = "${var.project_name}-igw" }
}
