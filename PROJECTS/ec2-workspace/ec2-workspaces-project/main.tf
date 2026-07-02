##############################################################
# main.tf — Root orchestrator
#
# Calls the ec2_instance module and passes:
#   1. lookup() resolved values (instance type/count for THIS workspace)
#   2. Network values REUSED from the VPC project's remote state
#      (no need to create subnet/SG here — already exist)
##############################################################

module "ec2_instance" {
  source = "./modules/ec2_instance"

  # ── From this project's own variables ──────────────────────
  ami           = var.ami
  project_name  = var.project_name
  key_pair_name = var.key_pair_name
  environment   = terraform.workspace   # "dev", "stage", or "prod"

  # ── lookup() — THE key concept of this project ─────────────
  # lookup(map, key, default)
  #   map     = var.instance_type            (the dev/stage/prod map)
  #   key     = terraform.workspace           (current workspace name)
  #   default = "t2.micro"                    (fallback if workspace not in map)
  instance_type  = lookup(var.instance_type, terraform.workspace, "t2.micro")
  instance_count = lookup(var.instance_count, terraform.workspace, 1)

  # ── REUSED from VPC project via remote state ───────────────
  # No duplicate subnet/SG code — pulling directly from the
  # network project's outputs
  subnet_id = data.terraform_remote_state.vpc.outputs.private_subnet_ids[0]
  sg_id     = data.terraform_remote_state.vpc.outputs.private_instance_sg_id
}
