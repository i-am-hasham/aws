##############################################################
# provider.tf — AWS Provider + Default Tags
#
# default_tags applies to EVERY resource automatically.
# No need to repeat tags in every resource block.
##############################################################

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Hasham"
    }
  }
}
