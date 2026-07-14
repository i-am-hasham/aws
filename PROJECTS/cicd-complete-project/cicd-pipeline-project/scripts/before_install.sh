#!/bin/bash
##############################################################
# scripts/before_install.sh
# Called by CodeDeploy at BeforeInstall hook
# Ensures Docker and AWS CLI are installed on the EC2
# This runs on FIRST deployment — subsequent runs skip installs
##############################################################

set -e

echo "=== BeforeInstall: Checking prerequisites ==="

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Docker not found — installing..."
    apt-get update -y
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ubuntu
    echo "Docker installed"
else
    echo "Docker already installed: $(docker --version)"
fi

# Ensure Docker is running
if ! systemctl is-active --quiet docker; then
    echo "Starting Docker service..."
    systemctl start docker
fi

# Install AWS CLI v2 if not present (needed for ECR login)
if ! command -v aws &> /dev/null; then
    echo "AWS CLI not found — installing..."
    apt-get install -y unzip curl
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip
    echo "AWS CLI installed"
else
    echo "AWS CLI already installed: $(aws --version)"
fi

# Create app directory if it doesn't exist
mkdir -p /home/ubuntu/cicd-app
chown ubuntu:ubuntu /home/ubuntu/cicd-app

echo "=== BeforeInstall: Complete ==="
