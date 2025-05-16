#!/bin/bash
set -e

# Script to build and deploy the Docker image locally with Microsoft integration
# This version retrieves sensitive credentials from AWS Secrets Manager

echo "Building Docker image with Technologymatch customizations and Microsoft integration..."

# Stop and remove existing container if it exists
if docker ps -a | grep -q technologymatch-webui; then
  echo "Stopping and removing existing container..."
  docker stop technologymatch-webui >/dev/null 2>&1 || true
  docker rm technologymatch-webui >/dev/null 2>&1 || true
fi

# Retrieve Microsoft credentials from AWS Secrets Manager
echo "Retrieving Microsoft credentials from AWS Secrets Manager..."
SECRET_JSON=$(aws --profile Technologymatch secretsmanager get-secret-value \
  --secret-id technologymatch-open-webui-ms-credentials \
  --query SecretString \
  --output text)

# Extract credentials from secret
ONEDRIVE_CLIENT_ID=$(echo $SECRET_JSON | jq -r '.ONEDRIVE_CLIENT_ID')
ONEDRIVE_SHAREPOINT_TENANT_ID=$(echo $SECRET_JSON | jq -r '.ONEDRIVE_SHAREPOINT_TENANT_ID')
MICROSOFT_CLIENT_ID=$(echo $SECRET_JSON | jq -r '.MICROSOFT_CLIENT_ID')
MICROSOFT_CLIENT_SECRET=$(echo $SECRET_JSON | jq -r '.MICROSOFT_CLIENT_SECRET')
MICROSOFT_CLIENT_TENANT_ID=$(echo $SECRET_JSON | jq -r '.MICROSOFT_CLIENT_TENANT_ID')

# Verify we got the secrets
if [ -z "$MICROSOFT_CLIENT_SECRET" ]; then
  echo "Error: Failed to retrieve secrets from AWS Secrets Manager"
  exit 1
fi

echo "Successfully retrieved Microsoft credentials"

# Build the Docker image with explicit build arguments
echo "Building Docker image..."
docker build -t technologymatch-openwebui:local \
  --build-arg ENABLE_ONEDRIVE_INTEGRATION=True \
  --build-arg ONEDRIVE_CLIENT_ID="$ONEDRIVE_CLIENT_ID" \
  --build-arg ONEDRIVE_SHAREPOINT_URL="https://thelaunchpadgroup.sharepoint.com" \
  --build-arg ONEDRIVE_SHAREPOINT_TENANT_ID="$ONEDRIVE_SHAREPOINT_TENANT_ID" \
  --build-arg MICROSOFT_CLIENT_ID="$MICROSOFT_CLIENT_ID" \
  --build-arg MICROSOFT_CLIENT_SECRET="$MICROSOFT_CLIENT_SECRET" \
  --build-arg MICROSOFT_CLIENT_TENANT_ID="$MICROSOFT_CLIENT_TENANT_ID" \
  --build-arg MICROSOFT_REDIRECT_URI="http://localhost:3000/oauth/microsoft/callback" \
  --build-arg ENABLE_OAUTH_SIGNUP=True \
  --build-arg OAUTH_MERGE_ACCOUNTS_BY_EMAIL=True \
  --build-arg OAUTH_ALLOWED_DOMAINS="technologymatch.com,thelaunchpad.tech" \
  -f technologymatch/Dockerfile.custom .

# Deploy locally
echo "Starting container locally..."
docker run -d --name technologymatch-webui -p 3000:8080 \
  -e WEBUI_URL="http://localhost:3000" \
  -e AUTH_BASE_URL="http://localhost:3000" \
  -e AUTH_REDIRECT_BASE_URL="http://localhost:3000" \
  -e LOG_LEVEL="DEBUG" \
  technologymatch-openwebui:local

echo "Deployment complete! Container is starting..."
echo "The application will be available at: http://localhost:3000"
echo ""
echo "Waiting for container to be healthy..."
attempt=1
max_attempts=30
until [ $attempt -gt $max_attempts ] || docker ps | grep -q "technologymatch-webui.*healthy"; do
  echo "Attempt $attempt/$max_attempts - Container still starting..."
  sleep 5
  attempt=$((attempt+1))
done

if [ $attempt -gt $max_attempts ]; then
  echo "Container failed to reach healthy state in time. Check logs with:"
  echo "docker logs technologymatch-webui"
else
  echo "Container is now healthy and ready for use!"
  echo ""
  echo "Access your application at: http://localhost:3000"
fi