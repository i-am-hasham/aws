##############################################################
# Module: Security Groups
#
# Creates 3 security groups:
#   1. bastion_sg         - SSH from your IP only
#   2. private_sg         - SSH only from bastion SG (not from IP)
#   3. alb_sg              - HTTP/HTTPS from internet
#
# KEY CONCEPT - SG-to-SG Referencing:
#   Instead of: cidr_blocks = ["10.0.1.0/24"]  (bastion's subnet)
#   We use:     security_groups = [aws_security_group.bastion.id]
#
#   Why is SG reference BETTER than CIDR?
#   - CIDR locks you to an IP range. If bastion moves to diff subnet -> update rules
#   - SG reference = "allow traffic from ANY instance that HAS this SG attached"
#   - More precise: only the bastion instance itself, not anything else in subnet
#   - Survives instance restarts, IP changes, subnet changes
##############################################################

# ── 1. Bastion Security Group ─────────────────────────────────
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Bastion host - SSH from admin IP only"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from your IP only - lockdown"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]   # Replace 0.0.0.0/0 with your actual IP in tfvars
  }

  egress {
    description = "Allow all outbound - bastion needs to reach private instances"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # -1 means ALL protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

# ── 2. Private Instance Security Group ───────────────────────
resource "aws_security_group" "private_instances" {
  name        = "${var.project_name}-private-sg"
  description = "Private EC2 instances - SSH only from bastion, HTTP only from ALB"
  vpc_id      = var.vpc_id

  # INBOUND: SSH allowed ONLY from bastion security group
  # This is SG-to-SG referencing - more secure than CIDR
  # Only instances that have bastion_sg attached can SSH here
  ingress {
    description     = "SSH from bastion host only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]  # Reference SG, not IP
  }

  # INBOUND: App traffic from ALB only
  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # OUTBOUND: Allow all (needed for apt install, Docker pull, etc.)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-private-sg"
  }
}

# ── 3. ALB Security Group ────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Application Load Balancer - HTTP and HTTPS from internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Forward to app servers"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}