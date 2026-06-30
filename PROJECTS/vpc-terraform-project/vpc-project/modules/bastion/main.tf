##############################################################
# Module: Bastion Host
#
# Creates:
#   aws_instance — a hardened EC2 in the PUBLIC subnet
#
# What is a Bastion Host?
#   A "jump server" — the ONLY machine in your infrastructure
#   that has a public IP and SSH open. To reach private EC2s:
#
#   Your laptop → SSH → Bastion (public subnet, public IP)
#                       → SSH → Private EC2 (private subnet, no public IP)
#
#   Internet has ONE attack surface (bastion) instead of N surfaces.
#   Lock down bastion tightly → all private resources are safe.
#
# Hardening applied in user_data:
#   - Disable password auth (key-only SSH)
#   - Install network diagnostic tools
#   - System updates on first boot
##############################################################

resource "aws_instance" "bastion" {
  ami                         = var.bastion_ami
  instance_type               = var.bastion_instance_type
  subnet_id                   = var.public_subnet_id      # Must be PUBLIC
  vpc_security_group_ids      = [var.bastion_sg_id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true  # Needs public IP so you can reach it

  # Runs once on first boot — hardens and sets up the bastion
  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get upgrade -y -q

    # Network troubleshooting tools — useful when debugging VPC connectivity
    apt-get install -y net-tools curl wget nmap traceroute

    # Key-only authentication — disable password login
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd

    echo "Bastion setup complete at $(date)" >> /var/log/bastion-setup.log
  EOF

  tags = {
    Name = "${var.project_name}-bastion"
    Role = "bastion-jump-server"
  }
}
