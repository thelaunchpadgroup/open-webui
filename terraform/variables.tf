# variables.tf - Variables for Open WebUI AWS deployment

variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
  default     = "openwebui"
}

variable "environment" {
  description = "Deployment environment (dev, staging, production)"
  type        = string
  default     = "production"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "ai.technologymatch.com"
}

variable "root_domain" {
  description = "Root domain for Route 53 zone lookup"
  type        = string
  default     = "technologymatch.com"
}

variable "openwebui_version" {
  description = "Open WebUI container image version/tag"
  type        = string
  default     = "main"
}

variable "container_cpu" {
  description = "CPU units for the container (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "container_memory" {
  description = "Memory for the container in MB"
  type        = number
  default     = 2048
}

variable "app_count" {
  description = "Number of instances of the application to run"
  type        = number
  default     = 2
}

variable "app_min_count" {
  description = "Minimum number of instances for auto scaling"
  type        = number
  default     = 2
}

variable "app_max_count" {
  description = "Maximum number of instances for auto scaling"
  type        = number
  default     = 6
}

variable "db_username" {
  description = "Username for the RDS PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Password for the RDS PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "anthropic_api_key" {
  description = "Anthropic API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "gemini_api_key" {
  description = "Google Gemini API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "opensearch_admin_user" {
  description = "Admin username for OpenSearch"
  type        = string
  default     = "admin"
}

variable "opensearch_admin_password" {
  description = "Admin password for OpenSearch"
  type        = string
  sensitive   = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {
    Project     = "OpenWebUI"
    ManagedBy   = "Terraform"
  }
}