##############################################################
# Module: RDS (MySQL Multi-AZ)
# Lives in PRIVATE DB subnets — completely isolated
# Multi-AZ = primary in AZ-a, standby in AZ-b
# Automatic failover if primary AZ fails
# Only accepts connections from app tier security group
##############################################################

# ── Security Group ────────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS - MySQL only from app tier"
  vpc_id      = var.vpc_id

  # Only accept MySQL connections from app servers
  # SG-to-SG reference: only EC2 instances with app_sg attached
  ingress {
    description     = "MySQL from app tier only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.app_sg_id]  # SG reference, not CIDR
  }

  # No outbound rules needed — RDS does not initiate connections

  tags = { Name = "${var.project_name}-rds-sg" }
}

# ── DB Subnet Group ───────────────────────────────────────────
# Tells RDS which subnets it can use for primary and standby
# Must have subnets in at least 2 AZs for Multi-AZ
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnet-group"
  description = "DB subnet group for Multi-AZ RDS"
  subnet_ids  = var.private_db_subnet_ids  # both DB subnets

  tags = { Name = "${var.project_name}-db-subnet-group" }
}

# ── RDS Instance ──────────────────────────────────────────────
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-rds"

  engine         = "mysql"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Multi-AZ: AWS creates primary + synchronous standby in different AZs
  # Automatic failover in ~1-2 minutes if primary fails
  # Standby is NOT readable — only for failover
  multi_az = true

  allocated_storage     = 20     # GB
  max_allocated_storage = 100    # auto-scaling storage up to 100 GB
  storage_type          = "gp2"
  storage_encrypted     = true   # encrypt at rest

  backup_retention_period = 7      # keep 7 days of backups
  backup_window           = "03:00-04:00"  # UTC - take backups at 3 AM
  maintenance_window      = "Mon:04:00-Mon:05:00"  # maintenance after backup

  skip_final_snapshot    = true   # for easy cleanup in dev
  deletion_protection    = false  # set true in production


  tags = { Name = "${var.project_name}-rds" }
}
