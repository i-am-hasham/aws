##############################################################
# main.tf — Root module: wires all child modules together
#
# Think of this file as the blueprint coordinator.
# Each module is a self-contained box. main.tf passes outputs
# from one module as inputs to the next.
#
# Dependency chain (Terraform auto-resolves these):
#   vpc → subnets (needs vpc_id, igw_id)
#   vpc → nat_gateway (needs public subnet IDs from subnets)
#   vpc → security_groups (needs vpc_id)
#   subnets → nat_gateway (nat_gateway_ids needed for route tables)
#   security_groups → bastion (needs bastion_sg_id)
#   subnets + security_groups → bastion (needs subnet_id, sg_id)
##############################################################

# ── Module 1: VPC ─────────────────────────────────────────────
# First thing created — everything else lives inside this VPC
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr     = var.vpc_cidr
  project_name = var.project_name
}

# ── Module 2: Subnets ─────────────────────────────────────────
# Creates 2 public + 2 private subnets, route tables, associations
# Needs vpc_id and igw_id from module.vpc
# Needs nat_gateway_ids from module.nat_gateway (for private routes)
module "subnets" {
  source = "./modules/subnets"

  vpc_id               = module.vpc.vpc_id
  igw_id               = module.vpc.igw_id
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  project_name         = var.project_name
  nat_gateway_ids      = module.nat_gateway.nat_gateway_ids
}

# ── Module 3: NAT Gateway ─────────────────────────────────────
# Creates Elastic IPs + NAT Gateways inside public subnets
# One NAT GW per AZ = high availability design
module "nat_gateway" {
  source = "./modules/nat_gateway"

  public_subnet_ids = module.subnets.public_subnet_ids
  project_name      = var.project_name
}

# ── Module 4: Security Groups ─────────────────────────────────
# Creates SGs for bastion, private instances, and ALB
# Uses SG-to-SG referencing for tightest security
module "security_groups" {
  source = "./modules/security_groups"

  vpc_id       = module.vpc.vpc_id
  my_ip        = var.my_ip
  project_name = var.project_name
}

# ── Module 5: Bastion Host ────────────────────────────────────
# Jump server in public subnet — only SSH entry point to private network
module "bastion" {
  source = "./modules/bastion"

  public_subnet_id      = module.subnets.public_subnet_ids[0]
  bastion_sg_id         = module.security_groups.bastion_sg_id
  bastion_instance_type = var.bastion_instance_type
  bastion_ami           = var.bastion_ami
  key_pair_name         = var.key_pair_name
  project_name          = var.project_name
}
