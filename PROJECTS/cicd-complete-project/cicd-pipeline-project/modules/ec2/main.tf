##############################################################
# modules/ec2/main.tf
# Creates: EC2 instance with CodeDeploy agent pre-installed
##############################################################

# ── Security Group ────────────────────────────────────────────
resource "aws_security_group" "app" {
  name        = "${var.project_name}-ec2-sg"
  description = "Flask app EC2 - HTTP and SSH"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP - Flask app on port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    description = "All outbound - pull Docker images, call AWS APIs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ec2-sg" }
}

# ── EC2 Instance ──────────────────────────────────────────────
resource "aws_instance" "app" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = var.key_pair_name
  iam_instance_profile        = var.instance_profile
  associate_public_ip_address = true

  # user_data: installs CodeDeploy agent on first boot
  # CodeDeploy agent listens for deployment instructions from CodeDeploy service
  # Without this agent installed, CodeDeploy cannot deploy to this EC2
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update packages
    apt-get update -y
    apt-get upgrade -y

    # Install required packages
    apt-get install -y ruby wget curl

    # Install CodeDeploy agent
    # The agent polls CodeDeploy service for deployment jobs
    cd /home/ubuntu
    wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
    chmod +x ./install
    ./install auto

    # Start and enable CodeDeploy agent
    systemctl start codedeploy-agent
    systemctl enable codedeploy-agent

    # Install Docker (CodeDeploy scripts also install it but good to have early)
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ubuntu

    # Install AWS CLI v2
    apt-get install -y unzip
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip

    echo "EC2 setup complete" >> /var/log/user-data.log
  EOF

  tags = {
    Name = "${var.project_name}-ec2"
    # CodeDeploy uses this tag to find deployment targets
    # Must match the tag in CodeDeploy deployment group
    DeploymentTarget = "true"
  }
}
