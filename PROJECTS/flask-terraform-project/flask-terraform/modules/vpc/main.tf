##############################################################
# Module: VPC (minimal — Flask project only needs one public subnet)
#
# Why simpler than the VPC project?
#   The VPC project needed: 2 public + 2 private subnets, NAT GW,
#   bastion host — because it is a full production network foundation.
#
#   This project just needs Flask accessible on a public IP.
#   So: 1 VPC + 1 public subnet + 1 IGW + 1 route table.
#   No NAT GW (no private subnets), no bastion (Flask EC2 is public).
##############################################################

# ── VPC ───────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${var.project_name}-vpc" }
}

# ── Internet Gateway ──────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# ── Public Subnet ─────────────────────────────────────────────
# Flask EC2 goes here — needs a public IP to be reachable
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true   # EC2 launched here gets public IP automatically
  tags = { Name = "${var.project_name}-public-subnet" }
}

# ── Route Table ───────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

# ── Route Table Association ───────────────────────────────────
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
