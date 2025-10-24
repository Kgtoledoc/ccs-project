variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "kinesis_stream_name" {
  description = "Kinesis stream name"
  type        = string
}

variable "dynamodb_telemetry_table_name" {
  description = "DynamoDB telemetry table name"
  type        = string
}

variable "aurora_cluster_id" {
  description = "Aurora cluster ID"
  type        = string
}

variable "elasticache_cluster_id" {
  description = "ElastiCache cluster ID"
  type        = string
  default     = ""
}

variable "load_balancer_name" {
  description = "Application Load Balancer name"
  type        = string
  default     = ""
}

variable "load_balancer_arn_suffix" {
  description = "Application Load Balancer ARN suffix"
  type        = string
  default     = ""
}

variable "api_gateway_name" {
  description = "API Gateway name"
  type        = string
  default     = ""
}

variable "emergency_workflow_arn" {
  description = "Emergency Step Function workflow ARN"
  type        = string
  default     = ""
}

variable "sns_alarm_topic_arn" {
  description = "SNS topic ARN for alarms"
  type        = string
}

variable "enable_xray" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable AWS GuardDuty"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 7
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

