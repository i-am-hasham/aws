##############################################################
# main.tf — Root orchestrator
# Dependency order:
#   1. VPC (foundation)
#   2. ALB (needs public subnets from VPC)
#   3. ASG (needs private subnets + ALB target group + ALB SG)
#   4. RDS (needs private DB subnets + app SG)
#   5. Monitoring (needs ALB ARN + RDS ID + ASG name)
##############################################################

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr                 = var.vpc_cidr
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  availability_zones       = var.availability_zones
  project_name             = var.project_name
}

module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids  # ALB in PUBLIC subnets
}

module "asg" {
  source = "./modules/asg"

  project_name           = var.project_name
  vpc_id                 = module.vpc.vpc_id
  ami                    = var.ami
  instance_type          = var.instance_type
  key_pair_name          = var.key_pair_name
  private_app_subnet_ids = module.vpc.private_app_subnet_ids  # EC2 in PRIVATE
  alb_sg_id              = module.alb.alb_sg_id
  target_group_arn       = module.alb.target_group_arn
  min_size               = var.asg_min_size
  max_size               = var.asg_max_size
  desired_size           = var.asg_desired_size
  my_ip                  = var.my_ip
}

module "rds" {
  source = "./modules/rds"

  project_name         = var.project_name
  vpc_id               = module.vpc.vpc_id
  private_db_subnet_ids = module.vpc.private_db_subnet_ids  # RDS in DEEPEST private
  app_sg_id            = module.asg.app_sg_id
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
  db_instance_class    = var.db_instance_class
  db_engine_version    = var.db_engine_version
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name   = var.project_name
  alert_email    = var.alert_email
  alb_arn_suffix = module.alb.alb_arn
  db_instance_id = module.rds.db_instance_id
  asg_name       = module.asg.asg_name
}
