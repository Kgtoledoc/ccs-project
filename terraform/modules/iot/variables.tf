variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kinesis_stream_name" {
  description = "Kinesis stream name for telemetry"
  type        = string
}

variable "emergency_queue_url" {
  description = "Emergency SQS queue URL"
  type        = string
}

variable "sns_owner_topic_arn" {
  description = "SNS topic ARN for owner alerts"
  type        = string
}

variable "dynamodb_telemetry_table_name" {
  description = "DynamoDB telemetry table name"
  type        = string
}

variable "iot_role_arn" {
  description = "IAM role ARN for IoT Core"
  type        = string
}

variable "anomaly_detector_lambda_arn" {
  description = "Lambda function ARN for anomaly detection"
  type        = string
  default     = ""
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
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

