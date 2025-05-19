#!/bin/bash
set -e

# Build and push custom Open WebUI Docker image to AWS ECR with versioning
# This script only handles building and pushing to ECR, not deployment

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile Technologymatch --query "Account" --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
  echo "Error: Could not get AWS account ID. Make sure you have the correct AWS credentials."
  exit 1
fi

# Generate version tag (date + git hash)
VERSION="$(date +%Y%m%d)-$(git rev-parse --short HEAD)"
echo "Building version: $VERSION"

# Create ECR repository if it doesn't exist
aws ecr describe-repositories --repository-names technologymatch/open-webui --profile Technologymatch > /dev/null 2>&1 || \
  aws ecr create-repository --repository-name technologymatch/open-webui --profile Technologymatch

# Log in to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region us-east-1 --profile Technologymatch | \
  docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Build the image with our custom Dockerfile
echo "Building Docker image with Technologymatch customizations..."

# Set environment variables for Microsoft 365 and OneDrive integration if provided
MS_ENV_ARGS=""

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

# Add sensitive credentials from Secrets Manager
MS_ENV_ARGS="$MS_ENV_ARGS --build-arg ONEDRIVE_CLIENT_ID=$ONEDRIVE_CLIENT_ID"
MS_ENV_ARGS="$MS_ENV_ARGS --build-arg ONEDRIVE_SHAREPOINT_TENANT_ID=$ONEDRIVE_SHAREPOINT_TENANT_ID"
MS_ENV_ARGS="$MS_ENV_ARGS --build-arg MICROSOFT_CLIENT_ID=$MICROSOFT_CLIENT_ID"
MS_ENV_ARGS="$MS_ENV_ARGS --build-arg MICROSOFT_CLIENT_SECRET=$MICROSOFT_CLIENT_SECRET"
MS_ENV_ARGS="$MS_ENV_ARGS --build-arg MICROSOFT_CLIENT_TENANT_ID=$MICROSOFT_CLIENT_TENANT_ID"

# Add non-sensitive configuration
PROD_DOMAIN=${PROD_DOMAIN:-"ai.technologymatch.com"}
PROD_PROTOCOL=${PROD_PROTOCOL:-"https"}
PROD_BASE_URL="${PROD_PROTOCOL}://${PROD_DOMAIN}"

MS_ENV_ARGS="$MS_ENV_ARGS --build-arg ENABLE_ONEDRIVE_INTEGRATION=True"
MS_ENV_ARGS="$MS_ENV_ARGS --build-arg ONEDRIVE_SHAREPOINT_URL=https://thelaunchpadgroup.sharepoint.com"
MS_ENV_ARGS="$MS_ENV_ARGS --build-arg MICROSOFT_REDIRECT_URI=${PROD_BASE_URL}/oauth/microsoft/callback"
MS_ENV_ARGS="$MS_ENV_ARGS --build-arg ENABLE_OAUTH_SIGNUP=True"
MS_ENV_ARGS="$MS_ENV_ARGS --build-arg OAUTH_MERGE_ACCOUNTS_BY_EMAIL=True"
MS_ENV_ARGS="$MS_ENV_ARGS --build-arg OAUTH_ALLOWED_DOMAINS=technologymatch.com,thelaunchpad.tech"
MS_ENV_ARGS="$MS_ENV_ARGS --build-arg ENABLE_LOGIN_FORM=False"

echo "Microsoft 365 configuration loaded from Secrets Manager."

# Build the Docker image with Technologymatch customizations
docker build -t open-webui:$VERSION -f technologymatch/Dockerfile.custom $MS_ENV_ARGS .

# Tag images with version and latest
echo "Tagging images..."
docker tag open-webui:$VERSION ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/technologymatch/open-webui:$VERSION
docker tag open-webui:$VERSION ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/technologymatch/open-webui:latest

# Push images to ECR
echo "Pushing images to ECR..."
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/technologymatch/open-webui:$VERSION
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/technologymatch/open-webui:latest

# Verify images in ECR
echo "Verifying images in ECR..."
aws ecr describe-images --repository-name technologymatch/open-webui --profile Technologymatch --query "imageDetails[?contains(imageTags, '$VERSION')]"

echo "========================================================"
echo "Build and push complete!"
echo "Image details:"
echo "Repository: ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/technologymatch/open-webui"
echo "Version tag: $VERSION"
echo "Latest tag: latest"
echo ""
echo "To deploy this version using Terraform:"
echo "1. Navigate to: /root/dev/forks/technologymatch/open-webui-helm-charts/technologymatch/terraform/environments/dev"
echo "2. Create or update terraform.tfvars with the following:"
echo "   use_custom_image = true"
echo "   custom_image_repository = \"${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/technologymatch/open-webui\""
echo "   custom_image_tag = \"$VERSION\""
echo "3. Run: terraform apply"
echo "========================================================"

# Save version information to a log file
mkdir -p "$(dirname "$0")/logs"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Built and pushed version $VERSION" >> "$(dirname "$0")/logs/image-builds.log"