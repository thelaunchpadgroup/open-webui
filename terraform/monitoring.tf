# monitoring.tf - Enhanced monitoring for Open WebUI

# Amazon OpenSearch Domain for advanced analytics
resource "aws_opensearch_domain" "main" {
  domain_name    = "${var.project_name}-analytics"
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type               = "t3.small.search" # For production with 20 users, t3.small should be sufficient
    instance_count              = 1
    zone_awareness_enabled      = false # Set to true and adjust for multi-AZ in production
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10 # GB
    volume_type = "gp3"
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = var.opensearch_admin_user
      master_user_password = var.opensearch_admin_password
    }
  }

  access_policies = <<CONFIG
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${aws_iam_role.ecs_task_role.arn}"
      },
      "Action": "es:*",
      "Resource": "arn:aws:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/${var.project_name}-analytics/*"
    }
  ]
}
CONFIG

  tags = var.common_tags
}

# AWS Caller Identity for account ID
data "aws_caller_identity" "current" {}

# Lambda function to process CloudWatch Logs and send to OpenSearch
resource "aws_iam_role" "logs_processing_lambda_role" {
  name = "${var.project_name}-logs-processing-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_policy" "logs_processing_lambda_policy" {
  name        = "${var.project_name}-logs-processing-policy"
  description = "Policy for logs processing Lambda"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Resource = "arn:aws:logs:*:*:*",
        Effect   = "Allow"
      },
      {
        Action = [
          "es:ESHttpPost",
          "es:ESHttpPut"
        ],
        Resource = "${aws_opensearch_domain.main.arn}/*",
        Effect   = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "logs_processing_lambda_attachment" {
  role       = aws_iam_role.logs_processing_lambda_role.name
  policy_arn = aws_iam_policy.logs_processing_lambda_policy.arn
}

# Create a zip file for the Lambda function code
data "archive_file" "logs_processor" {
  type        = "zip"
  output_path = "${path.module}/logs_processor.zip"

  source {
    content = <<EOF
import json
import base64
import gzip
import boto3
import os
import re
import urllib.request
import datetime
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
opensearch_domain = os.environ['OPENSEARCH_DOMAIN']

def lambda_handler(event, context):
    # Get the log data from the event
    cw_data = event['awslogs']['data']
    compressed_payload = base64.b64decode(cw_data)
    uncompressed_payload = gzip.decompress(compressed_payload)
    payload = json.loads(uncompressed_payload)
    
    # Process the log events
    log_events = payload['logEvents']
    
    # Batch the events for OpenSearch
    actions = []
    
    for event in log_events:
        # Try to parse the log message as JSON
        try:
            log_message = json.loads(event['message'])
            
            # Check if this is a login event
            if 'event' in log_message and log_message['event'] == 'login':
                index_data = {
                    'timestamp': datetime.datetime.fromtimestamp(event['timestamp']/1000.0).isoformat(),
                    'user_id': log_message.get('user_id', 'unknown'),
                    'username': log_message.get('username', 'unknown'),
                    'event_type': 'login',
                    'success': log_message.get('success', True),
                    'source_ip': log_message.get('source_ip', 'unknown')
                }
                
                # Add to batch
                actions.append(json.dumps({"index": {"_index": "openwebui-logins"}}))
                actions.append(json.dumps(index_data))
                
            # Check if this is a prompt event    
            elif 'event' in log_message and log_message['event'] == 'prompt':
                index_data = {
                    'timestamp': datetime.datetime.fromtimestamp(event['timestamp']/1000.0).isoformat(),
                    'user_id': log_message.get('user_id', 'unknown'),
                    'username': log_message.get('username', 'unknown'),
                    'event_type': 'prompt',
                    'model': log_message.get('model', 'unknown'),
                    'token_count': log_message.get('token_count', 0),
                    'prompt_length': log_message.get('prompt_length', 0) 
                }
                
                # Add to batch
                actions.append(json.dumps({"index": {"_index": "openwebui-prompts"}}))
                actions.append(json.dumps(index_data))
                
        except json.JSONDecodeError:
            # Not JSON, look for patterns in raw logs
            message = event['message']
            
            # Example pattern matching for non-JSON logs
            login_pattern = re.search(r'User login: (\S+)', message)
            if login_pattern:
                username = login_pattern.group(1)
                index_data = {
                    'timestamp': datetime.datetime.fromtimestamp(event['timestamp']/1000.0).isoformat(),
                    'username': username,
                    'event_type': 'login',
                    'source': 'raw_log'
                }
                
                # Add to batch
                actions.append(json.dumps({"index": {"_index": "openwebui-logins"}}))
                actions.append(json.dumps(index_data))
    
    # If we have actions to perform, send to OpenSearch
    if actions:
        # Format the OpenSearch bulk API request
        bulk_body = '\n'.join(actions) + '\n'
        
        # Send to OpenSearch
        url = f'https://{opensearch_domain}/_bulk'
        headers = {'Content-Type': 'application/json'}
        
        req = urllib.request.Request(url, data=bulk_body.encode('utf-8'), headers=headers, method='POST')
        
        try:
            with urllib.request.urlopen(req) as response:
                response_body = response.read()
                logger.info(f"OpenSearch response: {response_body}")
                return {
                    'statusCode': 200,
                    'body': f'Successfully processed {len(log_events)} log events'
                }
        except Exception as e:
            logger.error(f"Error sending to OpenSearch: {str(e)}")
            return {
                'statusCode': 500,
                'body': f'Error sending to OpenSearch: {str(e)}'
            }
    
    return {
        'statusCode': 200,
        'body': 'No relevant events to process'
    }
EOF
    filename = "index.py"
  }
}

resource "aws_lambda_function" "logs_processor" {
  function_name    = "${var.project_name}-logs-processor"
  filename         = data.archive_file.logs_processor.output_path
  source_code_hash = data.archive_file.logs_processor.output_base64sha256
  role             = aws_iam_role.logs_processing_lambda_role.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      OPENSEARCH_DOMAIN = aws_opensearch_domain.main.endpoint
    }
  }

  tags = var.common_tags
}

# CloudWatch Log Subscription Filter for processing application logs
resource "aws_cloudwatch_log_subscription_filter" "app_logs_filter" {
  name            = "${var.project_name}-app-logs-filter"
  log_group_name  = aws_cloudwatch_log_group.ecs_logs.name
  filter_pattern  = "{ $.event = \"login\" || $.event = \"prompt\" }"
  destination_arn = aws_lambda_function.logs_processor.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.logs_processor.function_name
  principal     = "logs.${var.aws_region}.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.ecs_logs.arn}:*"
}

# Amazon QuickSight for dashboards and reporting (requires manual setup in AWS console after deployment)
# This section documents the required steps but does not create resources due to QuickSight's unique setup requirements

# Add custom environment variables to the ECS task definition for enhanced logging
locals {
  updated_container_definitions = jsondecode(aws_ecs_task_definition.app.container_definitions)
}

# Update the task definition to include logging-specific environment variables
resource "aws_ecs_task_definition" "app_with_logging" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode(
    [
      merge(
        local.updated_container_definitions[0],
        {
          environment = concat(
            local.updated_container_definitions[0].environment,
            [
              { name = "ENABLE_DETAILED_LOGGING", value = "true" },
              { name = "LOG_FORMAT", value = "json" }
            ]
          )
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
              "awslogs-region"        = var.aws_region
              "awslogs-stream-prefix" = "ecs"
            }
          }
        }
      )
    ]
  )

  tags = var.common_tags
}