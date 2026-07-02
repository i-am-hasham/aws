##############################################################
# remote_state.tf — Reuse the VPC project instead of rebuilding it
#
# This reads the OUTPUTS of the vpc-terraform-project (VPC, subnets,
# security groups, etc.) directly from its S3 state file.
#
# WHY this instead of recreating VPC/subnets here?
#   - No duplicate code — the network layer is built once
#   - If VPC project changes (new subnet, new SG rule), this
#     project automatically sees the update next time it runs
#   - This is the real-world pattern: network team owns VPC,
#     app team consumes it via remote state
#
# PREREQUISITE: The VPC project must be applied (terraform apply)
# before running this project, because we need its real outputs.
# If you destroyed it, re-apply it first:
#   cd ../vpc-terraform-project/vpc-project/
#   terraform apply
##############################################################

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "hasham-vpc-project-tfstate"
    key    = "vpc-project/terraform.tfstate"   # path used by the VPC project
    region = "us-east-1"
  }
}

# Values we will reuse from the VPC project:
#   data.terraform_remote_state.vpc.outputs.private_subnet_ids
#   data.terraform_remote_state.vpc.outputs.private_instance_sg_id
#   data.terraform_remote_state.vpc.outputs.vpc_id
