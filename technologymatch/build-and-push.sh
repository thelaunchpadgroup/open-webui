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
docker build -t open-webui:$VERSION -f technologymatch/Dockerfile.custom .

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