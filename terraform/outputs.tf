output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.networking.vpc_cidr
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.networking.public_subnet_ids
}

# IoT Outputs
output "iot_endpoint" {
  description = "AWS IoT Core endpoint"
  value       = module.iot.iot_endpoint
}

output "iot_thing_type_arn" {
  description = "IoT Thing Type ARN"
  value       = module.iot.thing_type_arn
}

# Streaming Outputs
output "kinesis_stream_arn" {
  description = "Kinesis Data Stream ARN"
  value       = module.streaming.kinesis_stream_arn
}

output "kinesis_stream_name" {
  description = "Kinesis Data Stream name"
  value       = module.streaming.kinesis_stream_name
}

output "emergency_queue_url" {
  description = "Emergency SQS Queue URL"
  value       = module.streaming.emergency_queue_url
}

output "emergency_queue_arn" {
  description = "Emergency SQS Queue ARN"
  value       = module.streaming.emergency_queue_arn
}

# Storage Outputs
output "dynamodb_telemetry_table_name" {
  description = "DynamoDB Telemetry table name"
  value       = module.storage.dynamodb_telemetry_table_name
}

output "dynamodb_incidents_table_name" {
  description = "DynamoDB Incidents table name"
  value       = module.storage.dynamodb_incidents_table_name
}

output "aurora_endpoint" {
  description = "Aurora PostgreSQL cluster endpoint"
  value       = module.storage.aurora_endpoint
  sensitive   = true
}

output "aurora_reader_endpoint" {
  description = "Aurora PostgreSQL reader endpoint"
  value       = module.storage.aurora_reader_endpoint
  sensitive   = true
}

output "s3_data_lake_bucket" {
  description = "S3 Data Lake bucket name"
  value       = module.storage.s3_data_lake_bucket
}

output "s3_videos_bucket" {
  description = "S3 Videos bucket name"
  value       = module.storage.s3_videos_bucket
}

output "elasticache_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.storage.elasticache_endpoint
  sensitive   = true
}

output "timestream_database_name" {
  description = "Timestream database name"
  value       = module.storage.timestream_database_name
}

# API Outputs
output "api_gateway_rest_url" {
  description = "API Gateway REST API endpoint URL"
  value       = module.api.api_gateway_rest_url
}

output "api_gateway_websocket_url" {
  description = "API Gateway WebSocket API endpoint URL"
  value       = module.api.api_gateway_websocket_url
}

output "appsync_graphql_url" {
  description = "AppSync GraphQL endpoint URL"
  value       = module.api.appsync_graphql_url
}

output "appsync_realtime_url" {
  description = "AppSync real-time endpoint URL"
  value       = module.api.appsync_realtime_url
}

# Compute Outputs
output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = module.compute.ecs_cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS Cluster ARN"
  value       = module.compute.ecs_cluster_arn
}

output "load_balancer_dns" {
  description = "Application Load Balancer DNS name"
  value       = module.compute.load_balancer_dns
}

output "load_balancer_arn" {
  description = "Application Load Balancer ARN"
  value       = module.compute.load_balancer_arn
}

# Security Outputs
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.security.cognito_user_pool_id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = module.security.cognito_user_pool_arn
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  value       = module.security.cognito_user_pool_client_id
  sensitive   = true
}

output "kms_key_id" {
  description = "KMS Key ID for encryption"
  value       = module.security.kms_key_id
}

output "kms_key_arn" {
  description = "KMS Key ARN"
  value       = module.security.kms_key_arn
}

output "waf_web_acl_id" {
  description = "WAF Web ACL ID"
  value       = module.security.waf_web_acl_id
}

# Workflows Outputs
# output "emergency_workflow_arn" {
#   description = "Emergency Step Function workflow ARN"
#   value       = module.workflows.emergency_workflow_arn
# }
# 
# output "business_workflow_arn" {
#   description = "Business Step Function workflow ARN"
#   value       = module.workflows.business_workflow_arn
# }
# 
# Monitoring Outputs
output "cloudwatch_log_group_names" {
  description = "CloudWatch Log Group names"
  value       = module.monitoring.log_group_names
}

# output "cloudwatch_dashboard_url" {
#   description = "CloudWatch Dashboard URL"
#   value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${module.monitoring.dashboard_name}"
# }

# Frontend Outputs
output "website_url" {
  description = "Website URL (CloudFront or custom domain)"
  value       = module.frontend.website_url
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.frontend.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.frontend.cloudfront_domain_name
}

output "s3_website_bucket" {
  description = "S3 bucket name for website"
  value       = module.frontend.s3_bucket_name
}

# Summary Output
output "deployment_summary" {
  description = "Deployment summary information"
  value = {
    environment       = var.environment
    region            = var.aws_region
    vpc_id            = module.networking.vpc_id
    website_url       = module.frontend.website_url
    api_rest_endpoint = module.api.api_gateway_rest_url
    api_ws_endpoint   = module.api.api_gateway_websocket_url
    graphql_endpoint  = module.api.appsync_graphql_url
    load_balancer_dns = module.compute.load_balancer_dns
    ecs_cluster       = module.compute.ecs_cluster_name
  }
}

