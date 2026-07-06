##############################################################
# main.tf — Provisions Flask EC2 with file + remote-exec
#
# Provisioner execution order (always this sequence):
#   1. Terraform creates EC2 instance
#   2. EC2 boots up (~30-60 seconds)
#   3. connection block establishes SSH
#   4. file provisioner copies app.py from local → EC2
#   5. remote-exec provisioner runs commands on EC2:
#        - apt update
#        - install pip + flask
#        - start flask with nohup
#   6. Terraform completes, outputs public IP
##############################################################

# ── Module 1: VPC ─────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = var.availability_zone
  project_name       = var.project_name
}

# ── Module 2: Security Group ──────────────────────────────────
module "security_group" {
  source = "./modules/security_group"

  vpc_id       = module.vpc.vpc_id
  my_ip        = var.my_ip
  flask_port   = var.flask_port
  project_name = var.project_name
}

# ── EC2 Instance with Provisioners ───────────────────────────
resource "aws_instance" "flask" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = module.vpc.public_subnet_id
  vpc_security_group_ids      = [module.security_group.sg_id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true

  tags = { Name = "${var.project_name}-ec2" }

  # Wait for EC2 to be fully ready before provisioners run
  user_data = <<-EOF
    #!/bin/bash
    systemctl enable ssh
    systemctl start ssh
  EOF

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    host        = self.public_ip
    timeout     = "10m"
    agent       = false
  }

  provisioner "file" {
    source      = "app.py"
    destination = "/home/ubuntu/app.py"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo DEBIAN_FRONTEND=noninteractive apt-get update -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3-pip python3-venv",
      "python3 -m venv /home/ubuntu/flask-env",
      "/home/ubuntu/flask-env/bin/pip install flask",
      "nohup /home/ubuntu/flask-env/bin/python /home/ubuntu/app.py > /home/ubuntu/flask.log 2>&1 &",
      "sleep 3",
      "echo 'Flask startup check:'",
      "ps aux | grep python | grep -v grep || echo 'WARNING: Flask may not have started'"
    ]
  }
}