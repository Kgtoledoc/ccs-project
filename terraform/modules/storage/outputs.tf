output "dynamodb_telemetry_table_name" {
  description = "DynamoDB Telemetry table name"
  value       = aws_dynamodb_table.telemetry.name
}

output "dynamodb_telemetry_table_arn" {
  description = "DynamoDB Telemetry table ARN"
  value       = aws_dynamodb_table.telemetry.arn
}

output "dynamodb_telemetry_stream_arn" {
  description = "DynamoDB Telemetry table stream ARN"
  value       = aws_dynamodb_table.telemetry.stream_arn
}

output "dynamodb_incidents_table_name" {
  description = "DynamoDB Incidents table name"
  value       = aws_dynamodb_table.incidents.name
}

output "dynamodb_incidents_table_arn" {
  description = "DynamoDB Incidents table ARN"
  value       = aws_dynamodb_table.incidents.arn
}

output "dynamodb_incidents_stream_arn" {
  description = "DynamoDB Incidents table stream ARN"
  value       = aws_dynamodb_table.incidents.stream_arn
}

output "dynamodb_alerts_config_table_name" {
  description = "DynamoDB Alerts Config table name"
  value       = aws_dynamodb_table.alerts_config.name
}

output "dynamodb_websocket_connections_table_name" {
  description = "DynamoDB WebSocket Connections table name"
  value       = aws_dynamodb_table.websocket_connections.name
}

output "aurora_cluster_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.main.id
}

output "aurora_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
}

output "aurora_reader_endpoint" {
  description = "RDS endpoint (same as primary for single instance)"
  value       = aws_db_instance.main.endpoint
}

output "aurora_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

output "aurora_port" {
  description = "RDS port"
  value       = aws_db_instance.main.port
}

output "elasticache_endpoint" {
  description = "ElastiCache primary endpoint"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "elasticache_reader_endpoint" {
  description = "ElastiCache reader endpoint"
  value       = aws_elasticache_replication_group.main.reader_endpoint_address
}

output "elasticache_port" {
  description = "ElastiCache port"
  value       = 6379
}

output "s3_data_lake_bucket" {
  description = "S3 Data Lake bucket name"
  value       = aws_s3_bucket.data_lake.id
}

output "s3_data_lake_bucket_arn" {
  description = "S3 Data Lake bucket ARN"
  value       = aws_s3_bucket.data_lake.arn
}

output "s3_videos_bucket" {
  description = "S3 Videos bucket name"
  value       = aws_s3_bucket.videos.id
}

output "s3_videos_bucket_arn" {
  description = "S3 Videos bucket ARN"
  value       = aws_s3_bucket.videos.arn
}

output "s3_logs_bucket" {
  description = "S3 Logs bucket name"
  value       = aws_s3_bucket.logs.id
}

output "s3_logs_bucket_arn" {
  description = "S3 Logs bucket ARN"
  value       = aws_s3_bucket.logs.arn
}

output "s3_logs_bucket_domain_name" {
  description = "S3 Logs bucket regional domain name"
  value       = aws_s3_bucket.logs.bucket_regional_domain_name
}

output "timestream_database_name" {
  description = "Timestream database name"
  value       = var.enable_timestream ? aws_timestreamwrite_database.main[0].database_name : ""
}

output "timestream_database_arn" {
  description = "Timestream database ARN"
  value       = var.enable_timestream ? aws_timestreamwrite_database.main[0].arn : ""
}

output "timestream_table_name" {
  description = "Timestream table name"
  value       = var.enable_timestream ? aws_timestreamwrite_table.vehicle_metrics[0].table_name : ""
}

output "timestream_table_arn" {
  description = "Timestream table ARN"
  value       = var.enable_timestream ? aws_timestreamwrite_table.vehicle_metrics[0].arn : ""
}

