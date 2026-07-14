#!/bin/bash
##############################################################
# scripts/stop_app.sh
# Called by CodeDeploy at ApplicationStop hook
# Stops and removes the old Docker container if it exists
##############################################################

set -e  # exit on any error

echo "=== ApplicationStop: Stopping old container ==="

CONTAINER_NAME="flask-cicd-app"

# Check if container is running
if docker ps -q -f name=${CONTAINER_NAME} | grep -q .; then
    echo "Stopping container: ${CONTAINER_NAME}"
    docker stop ${CONTAINER_NAME}
    echo "Container stopped"
else
    echo "Container ${CONTAINER_NAME} is not running — skipping stop"
fi

# Remove container if it exists (stopped or running)
if docker ps -aq -f name=${CONTAINER_NAME} | grep -q .; then
    echo "Removing container: ${CONTAINER_NAME}"
    docker rm ${CONTAINER_NAME}
    echo "Container removed"
else
    echo "Container ${CONTAINER_NAME} does not exist — skipping remove"
fi

echo "=== ApplicationStop: Complete ==="
