##############################################################
# Module: EC2 Instance (workspace-aware)
#
# Creates N EC2 instances using the instance_type and
# instance_count that were already resolved by lookup() in
# root main.tf. This module itself does not know about
# workspaces or lookup() — it just receives final values.
#
# This separation matters: the module is reusable. You could
# call this same module from a totally different project that
# doesn't use workspaces at all, and it would work the same way.
##############################################################

resource "aws_instance" "app" {
  count = var.instance_count   # dev=1, stage=1, prod=2 (resolved upstream)

  ami                    = var.ami
  instance_type          = var.instance_type   # already resolved: t2.micro / t2.medium / t2.xlarge
  subnet_id              = var.subnet_id       # reused private subnet from VPC project
  vpc_security_group_ids = [var.sg_id]         # reused private SG from VPC project
  key_name               = var.key_pair_name

  tags = {
    Name        = "${var.project_name}-${var.environment}-${count.index + 1}"
    Environment = var.environment
    Index       = count.index + 1
  }
}
