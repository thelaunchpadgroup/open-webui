# Open WebUI AWS Deployment

This directory contains Terraform configuration for deploying Open WebUI to AWS. The configuration:

- Creates a VPC with public and private subnets across multiple AZs
- Sets up RDS PostgreSQL for database storage
- Configures S3 for file storage
- Deploys the Open WebUI container to ECS Fargate
- Configures load balancing and auto-scaling
- Sets up Route 53 for custom domain (ai.technologymatch.com)
- Implements SSL/TLS with AWS Certificate Manager
- Establishes monitoring and logging with CloudWatch
- Stores API keys securely in AWS Secrets Manager
- Protects the application with AWS WAF (Web Application Firewall)
- Includes advanced usage analytics with OpenSearch and CloudWatch Logs

## Prerequisites

- AWS CLI configured with the Technologymatch profile
- Terraform installed (v1.0.0+)
- A domain in Route 53 (technologymatch.com)

## Deployment Instructions

1. Copy the example variables file and customize it:
   ```
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your specific values:
   - Set your database credentials
   - Add your API keys for OpenAI, Anthropic, and Gemini
   - Set a secure password for OpenSearch admin access
   - Customize any other settings as needed

3. Initialize and apply the Terraform configuration:
   ```
   terraform init
   terraform plan
   terraform apply
   ```

4. After deployment completes, Open WebUI will be available at:
   https://ai.technologymatch.com

## Configuration Options

The deployment can be customized through the `terraform.tfvars` file:

- `aws_region`: The AWS region for deployment (default: us-east-1)
- `openwebui_version`: The container image version (default: main)
- `container_cpu` and `container_memory`: Resources for the container
- `app_count`: Initial number of instances (default: 2)
- `app_min_count` and `app_max_count`: Auto-scaling limits

## Storage

- **Database**: RDS PostgreSQL for persistence
- **Files**: S3 bucket for file uploads and attachments

## Security

- SSL/TLS encryption for all traffic
- AWS WAF protection against common web vulnerabilities
- Rate limiting to prevent abuse
- API keys stored in AWS Secrets Manager
- VPC with private subnets for backend services
- Security groups with minimal required access

## AWS WAF Protection

The deployment includes AWS WAF with:

- **Core Rule Set**: Protection against common web exploits (XSS, SQL injection, etc.)
- **Known Bad Inputs**: Blocks requests containing known malicious inputs
- **SQL Injection Protection**: Additional protection against SQL injection attacks
- **Rate Limiting**: Prevents abuse by limiting requests per IP address
- **Geo-Restriction**: (Optional, commented out) Ability to restrict access by country

WAF logs are stored in an S3 bucket with lifecycle policies for cost management.

## Usage Analytics

The deployment includes a comprehensive analytics solution to track:

- **User logins**: Who is logging in and when
- **Login patterns**: Days of the week, time of day for logins
- **Prompt usage**: Number of prompts per user
- **Model usage**: Which models are being used most frequently

The analytics system consists of:

1. **Enhanced logging in the ECS container**: Structured JSON logs for key events
2. **CloudWatch Logs**: Collection of all application logs
3. **Lambda processor**: Extracts and transforms login/usage events
4. **OpenSearch domain**: Stores and indexes usage data
5. **QuickSight**: For creating dashboards (setup required in AWS console)

### Setting up QuickSight dashboards

After deployment, follow these steps to set up QuickSight dashboards:

1. Log in to the AWS Console and navigate to QuickSight
2. Sign up for QuickSight if not already done
3. Create a new data source pointing to the OpenSearch domain
4. Create analyses and dashboards using the login and prompt indices:
   - `openwebui-logins`: Contains login events
   - `openwebui-prompts`: Contains prompt usage events

Example dashboards to create:
- User activity by day of week
- Login frequency by user
- Prompt usage by model type
- Token consumption trends

## Monitoring

- CloudWatch for logs and metrics
- Alarms for high CPU and memory utilization
- WAF logs for security monitoring
- OpenSearch for detailed usage analytics

## Maintenance

To update the deployment:

1. Update the `openwebui_version` in terraform.tfvars to the desired version
2. Run `terraform apply` to apply the changes

For significant changes like database migrations, refer to the Open WebUI documentation.

## Troubleshooting

- Check CloudWatch logs for application errors
- Verify security group rules if there are connectivity issues
- Review WAF logs for blocked requests
- For database connectivity problems, ensure the security groups permit traffic

## Cost Considerations

This deployment uses several AWS services with associated costs:
- ECS Fargate for compute
- RDS for database
- ALB for load balancing
- S3 for storage
- CloudWatch for logging and monitoring
- WAF for security
- OpenSearch for analytics

Adjust the configuration to match your requirements and budget.