variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kinesis_shard_count" {
  description = "Number of shards for Kinesis Data Stream"
  type        = number
  default     = 10
}

variable "kinesis_retention_period" {
  description = "Kinesis data retention in hours"
  type        = number
  default     = 24
}

variable "s3_data_lake_bucket" {
  description = "S3 bucket name for data lake"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
}

variable "enable_encryption" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

variable "firehose_role_arn" {
  description = "IAM role ARN for Firehose"
  type        = string
  default     = ""
}

variable "eventbridge_role_arn" {
  description = "IAM role ARN for EventBridge"
  type        = string
  default     = ""
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

