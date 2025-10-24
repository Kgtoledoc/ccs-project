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

variable "load_balancer_arn" {
  description = "Application Load Balancer ARN"
  type        = string
}

variable "load_balancer_dns" {
  description = "Application Load Balancer DNS name"
  type        = string
}

variable "websocket_handler_arn" {
  description = "WebSocket handler Lambda function ARN"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  type        = string
}

variable "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  type        = string
  default     = ""
}

variable "dynamodb_telemetry_table_name" {
  description = "DynamoDB telemetry table name"
  type        = string
}

variable "appsync_role_arn" {
  description = "IAM role ARN for AppSync"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
}

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

