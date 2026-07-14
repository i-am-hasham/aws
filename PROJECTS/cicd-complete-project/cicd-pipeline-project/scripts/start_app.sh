#!/bin/bash
##############################################################
# scripts/start_app.sh
# Called by CodeDeploy at ApplicationStart hook
# 1. Logs into ECR
# 2. Pulls the new Docker image
# 3. Runs the container
##############################################################

set -e

echo "=== ApplicationStart: Starting new container ==="

# Read values from deploy_vars.json written by CodeBuild
DEPLOY_VARS="/home/ubuntu/cicd-app/deploy_vars.json"

if [ ! -f "$DEPLOY_VARS" ]; then
    echo "ERROR: deploy_vars.json not found at ${DEPLOY_VARS}"
    exit 1
fi

# Parse JSON values (using python3 which is always available on Ubuntu)
IMAGE_URI=$(python3 -c "import json; d=json.load(open('${DEPLOY_VARS}')); print(d['image_uri'])")
CONTAINER_NAME=$(python3 -c "import json; d=json.load(open('${DEPLOY_VARS}')); print(d['container_name'])")
APP_PORT=$(python3 -c "import json; d=json.load(open('${DEPLOY_VARS}')); print(d['app_port'])")

echo "Image URI     : ${IMAGE_URI}"
echo "Container Name: ${CONTAINER_NAME}"
echo "App Port      : ${APP_PORT}"

# Get region and account for ECR login
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URI}
echo "ECR login successful"

# Pull the new image
echo "Pulling image: ${IMAGE_URI}"
docker pull ${IMAGE_URI}
echo "Image pulled"

# Run the container
# -d           = detached (background)
# --name       = container name (used by stop script)
# --restart    = restart unless explicitly stopped
# -p 80:5000   = map host port 80 to container port 5000
#                (access app on port 80, app runs on 5000)
echo "Starting container..."
docker run -d \
    --name ${CONTAINER_NAME} \
    --restart unless-stopped \
    -p 80:${APP_PORT} \
    -e APP_VERSION=$(date +%Y%m%d%H%M%S) \
    ${IMAGE_URI}

echo "Container started successfully"
echo "App should be accessible on port 80"
echo "=== ApplicationStart: Complete ==="
