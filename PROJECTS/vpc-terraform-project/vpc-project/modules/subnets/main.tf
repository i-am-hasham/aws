##############################################################
# Module: Subnets
#
# Creates:
#   Public subnets  (map_public_ip_on_launch = true)
#   Private subnets (map_public_ip_on_launch = false)
#   Public route table  → 0.0.0.0/0 via IGW
#   Private route tables → 0.0.0.0/0 via NAT GW (one per AZ)
#   All route table associations
#
# KEY DESIGN — Why one private route table PER AZ?
#   Each AZ gets its OWN NAT Gateway (see nat_gateway module).
#   If AZ-a fails and you had one shared route table pointing
#   to AZ-a's NAT GW → ALL private subnets lose internet.
#   One route table per AZ = failure is contained to that AZ only.
##############################################################

# ── Public Subnets ────────────────────────────────────────────
# count = 2 → creates subnet[0] and subnet[1] from the CIDR list
# Resources here: Bastion Host, NAT Gateway, Application Load Balancer
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id            = var.vpc_id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Critical: instances here automatically get a public IP
  # Without this, Bastion Host can't be reached from internet
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Type = "public"
    AZ   = var.availability_zones[count.index]
  }
}

# ── Private Subnets ───────────────────────────────────────────
# Resources here: EC2 app servers, RDS databases
# No public IPs — internet can NEVER initiate a connection here
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = var.vpc_id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = false   # NEVER give private instances public IPs

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    Type = "private"
    AZ   = var.availability_zones[count.index]
  }
}

# ── Public Route Table ────────────────────────────────────────
# One shared route table for ALL public subnets
# Rule: any traffic going to the internet (0.0.0.0/0) → use IGW
resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw_id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

# Attach route table to each public subnet
# A route table without an association does NOTHING
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Private Route Tables (one per AZ) ─────────────────────────
# Each private subnet gets its OWN route table pointing to its OWN NAT GW
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.nat_gateway_ids[count.index]  # same-AZ NAT GW
  }

  tags = {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
    AZ   = var.availability_zones[count.index]
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
