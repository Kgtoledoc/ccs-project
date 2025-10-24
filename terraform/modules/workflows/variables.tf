variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "step_functions_role_arn" {
  description = "IAM role ARN for Step Functions"
  type        = string
}

variable "eventbridge_role_arn" {
  description = "IAM role ARN for EventBridge"
  type        = string
  default     = ""
}

variable "sns_authorities_topic_arn" {
  description = "SNS topic ARN for authorities alerts"
  type        = string
}

variable "sns_owner_topic_arn" {
  description = "SNS topic ARN for owner alerts"
  type        = string
}

variable "sns_manager_topic_arn" {
  description = "SNS topic ARN for manager notifications"
  type        = string
}

variable "dynamodb_incidents_table_name" {
  description = "DynamoDB incidents table name"
  type        = string
}

variable "emergency_queue_url" {
  description = "Emergency SQS queue URL"
  type        = string
}

variable "video_activation_lambda_arn" {
  description = "Lambda function ARN for video activation"
  type        = string
  default     = ""
}

variable "validation_lambda_arn" {
  description = "Lambda function ARN for customer validation"
  type        = string
  default     = ""
}

variable "contract_creation_lambda_arn" {
  description = "Lambda function ARN for contract creation"
  type        = string
  default     = ""
}

variable "approval_handler_lambda_arn" {
  description = "Lambda function ARN for approval handling"
  type        = string
  default     = ""
}

variable "payment_processing_lambda_arn" {
  description = "Lambda function ARN for payment processing"
  type        = string
  default     = ""
}

variable "service_activation_lambda_arn" {
  description = "Lambda function ARN for service activation"
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

