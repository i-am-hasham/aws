#!/bin/bash
##############################################################
# scripts/validate.sh
# Called by CodeDeploy at ValidateService hook
# Verifies the new container is running and app responds
# If this script fails, CodeDeploy marks deployment as failed
# and can trigger automatic rollback
##############################################################

set -e

echo "=== ValidateService: Checking app health ==="

CONTAINER_NAME="flask-cicd-app"
MAX_RETRIES=10
RETRY_INTERVAL=3

# Check 1: Is the container running?
echo "Check 1: Is container running?"
if ! docker ps -q -f name=${CONTAINER_NAME} | grep -q .; then
    echo "FAILED: Container ${CONTAINER_NAME} is not running"
    docker ps -a
    exit 1
fi
echo "PASS: Container is running"

# Check 2: Does the app respond on port 80?
echo "Check 2: Does app respond on port 80?"
for i in $(seq 1 $MAX_RETRIES); do
    if curl -f -s http://localhost:80/health > /dev/null 2>&1; then
        echo "PASS: App responded to health check on attempt ${i}"
        break
    fi
    if [ $i -eq $MAX_RETRIES ]; then
        echo "FAILED: App did not respond after ${MAX_RETRIES} attempts"
        echo "Container logs:"
        docker logs ${CONTAINER_NAME} --tail 20
        exit 1
    fi
    echo "Attempt ${i} failed, retrying in ${RETRY_INTERVAL}s..."
    sleep ${RETRY_INTERVAL}
done

# Check 3: Get health status from app
echo "Check 3: Health endpoint content"
HEALTH_RESPONSE=$(curl -s http://localhost:80/health)
echo "Health response: ${HEALTH_RESPONSE}"

echo "=== ValidateService: ALL CHECKS PASSED ==="
echo "Deployment successful! App is running and healthy."
