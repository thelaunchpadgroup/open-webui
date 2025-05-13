# Open WebUI Custom Image Workflow

This document describes the process for building, pushing, and deploying custom Open WebUI Docker images with version tracking using AWS ECR and Terraform.

## Overview

The custom image workflow allows you to:

1. Build customized versions of the Open WebUI Docker image
2. Push these images to a private AWS ECR repository
3. Deploy specific versions to your Kubernetes cluster using Terraform
4. Roll back to previous versions as needed

## Prerequisites

- AWS CLI configured with a `Technologymatch` profile
- Docker installed and running
- Access to the Open WebUI repository
- Terraform configured for your environment

## Build and Push Process

The `build-and-push.sh` script handles building and pushing custom images to AWS ECR. It automatically:

- Generates a version tag using the current date and git commit hash
- Creates an ECR repository if it doesn't exist
- Builds the Docker image
- Tags the image with both the specific version and "latest"
- Pushes both tags to ECR
- Provides instructions for deployment

### Usage

#### Testing Locally First (Recommended)

Before pushing to ECR, you can test your customized image locally:

```bash
# Navigate to the Open WebUI repository root
cd /root/dev/forks/technologymatch/open-webui

# Build the image locally using custom Dockerfile
docker build -t technologymatch-openwebui:local -f technologymatch/Dockerfile.custom .

# Run the container locally
docker run -d --name technologymatch-webui -p 3000:8080 technologymatch-openwebui:local

# View the container logs
docker logs -f technologymatch-webui

# Access the UI in your browser at http://localhost:3000

# When done testing, stop and remove the container
docker stop technologymatch-webui
docker rm technologymatch-webui
```

#### Building and Pushing to ECR

Once you've verified your changes locally, you can build and push to ECR:

```bash
# Navigate to the Open WebUI repository root
cd /root/dev/forks/technologymatch/open-webui

# Run the script
./technologymatch/build-and-push.sh
```

### Versioning

The script automatically creates version tags in the format:
```
YYYYMMDD-<git-hash>
```

This provides a clear timeline of builds and enables easy tracing back to the exact code used for each image.

## Deployment with Terraform

After building and pushing your custom image, you can deploy it using Terraform.

### Steps to Deploy

1. Navigate to your environment directory:
   ```bash
   cd /root/dev/forks/technologymatch/open-webui-helm-charts/technologymatch/terraform/environments/dev
   ```

2. Create or update `terraform.tfvars` with the custom image configuration:
   ```terraform
   use_custom_image = true
   custom_image_repository = "<account-id>.dkr.ecr.us-east-1.amazonaws.com/technologymatch/open-webui"
   custom_image_tag = "<version-tag>"
   ```

3. Environment Variables

The deployment includes the following custom environment variables:

- `WEBUI_NAME`: Set to "Technologymatch AI" - This customizes the name displayed in the UI

4. Apply the changes:
   ```bash
   terraform apply
   ```

5. Verify the deployment:
   ```bash
   kubectl get pods -n open-webui-dev
   kubectl describe deployment open-webui -n open-webui-dev
   ```

### Rolling Back

To roll back to a previous version:

1. Update `terraform.tfvars` with the previous version tag
2. Run `terraform apply`

## Image History

The script maintains a log of all builds at:
```
/root/dev/forks/technologymatch/open-webui/technologymatch/logs/image-builds.log
```

Use this log to track build history and identify available versions for rollback.

## Advanced Customization

### Customizing the Docker Build

The build process uses a custom Dockerfile (`Dockerfile.custom`) that:

1. Includes all custom branding assets from the `technologymatch/static` directory
2. Updates the application name to "Technologymatch AI" and removes the "(Open WebUI)" suffix
3. Replaces all favicons, logos, and splash images with Technologymatch branded versions

#### Adding or Updating Custom Assets

To add or update custom assets:

1. Place your custom assets in the `technologymatch/static/` directory:
   ```bash
   # Example structure of custom assets
   technologymatch/static/
   ├── apple-touch-icon.png
   ├── favicon-96x96.png
   ├── favicon-dark.png
   ├── favicon.ico
   ├── favicon.png
   ├── favicon.svg
   ├── logo.png             # Main application logo
   ├── splash-dark.png
   ├── splash.png
   └── web-app-manifest-*.png
   ```

2. Ensure new assets are added to both places in the Dockerfile.custom:
   - In the frontend build section (around line 27)
   - In the backend copy section (around line 172)

#### Making Additional Modifications

If you need to make other modifications:

1. Update the custom assets in the `technologymatch/static` directory
2. Modify the `technologymatch/Dockerfile.custom` file as needed
3. Make code changes to the Open WebUI repository as needed
4. Commit your changes (this ensures the git hash in the version tag reflects your modifications)
5. Test locally first using the instructions above
6. Run the build-and-push script when ready

### Using Different AWS Regions or Profiles

The script defaults to:
- AWS Region: `us-east-1`
- AWS Profile: `Technologymatch`

To use a different region or profile, modify the appropriate lines in the script.

## Troubleshooting

### Common Issues

1. **Docker build fails**
   - Check that you have sufficient disk space
   - Ensure Docker is running
   - Verify that the Open WebUI repository is properly structured

2. **ECR push fails**
   - Verify your AWS credentials and permissions
   - Ensure you have access to create/push to ECR repositories
   - Check your network connection

3. **Terraform deployment issues**
   - Ensure the ECR repository URL and image tag are correct
   - Verify that your EKS cluster has access to pull from ECR
   - Check for any typos in the terraform.tfvars file

For any other issues, check the script output for error messages that may indicate the problem.