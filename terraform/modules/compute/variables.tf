variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "ecs_security_group_id" {
  description = "ECS security group ID"
  type        = string
}

variable "lambda_security_group_id" {
  description = "Lambda security group ID"
  type        = string
}

# Lambda Configuration
variable "lambda_execution_role_arn" {
  description = "IAM role ARN for Lambda execution"
  type        = string
}

variable "lambda_telemetry_memory" {
  description = "Memory allocation for telemetry processor Lambda"
  type        = number
  default     = 512
}

variable "lambda_telemetry_timeout" {
  description = "Timeout for telemetry processor Lambda in seconds"
  type        = number
  default     = 60
}

variable "lambda_concurrent_executions" {
  description = "Reserved concurrent executions for Lambda functions"
  type        = number
  default     = 100
}

# ECS Configuration
variable "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "ecs_cpu" {
  description = "CPU units for ECS tasks"
  type        = number
  default     = 512
}

variable "ecs_memory" {
  description = "Memory for ECS tasks in MB"
  type        = number
  default     = 1024
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "ecs_min_capacity" {
  description = "Minimum number of ECS tasks for auto-scaling"
  type        = number
  default     = 2
}

variable "ecs_max_capacity" {
  description = "Maximum number of ECS tasks for auto-scaling"
  type        = number
  default     = 10
}

variable "ecr_repository_url" {
  description = "ECR repository URL for Docker images"
  type        = string
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/ccs"
}

# Streaming Resources
variable "kinesis_stream_arn" {
  description = "Kinesis stream ARN"
  type        = string
}

variable "emergency_queue_arn" {
  description = "Emergency SQS queue ARN"
  type        = string
}

variable "emergency_queue_url" {
  description = "Emergency SQS queue URL"
  type        = string
}

# Storage Resources
variable "dynamodb_telemetry_table_name" {
  description = "DynamoDB telemetry table name"
  type        = string
}

variable "dynamodb_websocket_connections_table_name" {
  description = "DynamoDB WebSocket connections table name"
  type        = string
}

variable "timestream_database_name" {
  description = "Timestream database name"
  type        = string
}

variable "timestream_table_name" {
  description = "Timestream table name"
  type        = string
}

variable "elasticache_endpoint" {
  description = "ElastiCache endpoint"
  type        = string
}

variable "s3_logs_bucket" {
  description = "S3 bucket for logs"
  type        = string
}

# Workflows
variable "emergency_workflow_arn" {
  description = "Emergency workflow Step Function ARN"
  type        = string
}

# API
variable "websocket_endpoint" {
  description = "WebSocket API endpoint"
  type        = string
  default     = ""
}

# Security
variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
}

# Monitoring
variable "enable_xray" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

