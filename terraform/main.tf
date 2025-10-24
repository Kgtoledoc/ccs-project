# CCS AWS Infrastructure - Main Configuration
# This is the root module that orchestrates all sub-modules

locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.additional_tags
  )

  name_prefix = "${var.project_name}-${var.environment}"
}

# ========================================
# NETWORKING MODULE
# ========================================
module "networking" {
  source = "./modules/networking"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  tags = local.common_tags
}

# ========================================
# SECURITY MODULE
# ========================================
module "security" {
  source = "./modules/security"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  enable_waf        = var.enable_waf
  enable_encryption = var.enable_encryption

  tags = local.common_tags
}

# ========================================
# IOT MODULE
# ========================================
module "iot" {
  source = "./modules/iot"

  project_name                  = var.project_name
  environment                   = var.environment
  kinesis_stream_name           = module.streaming.kinesis_stream_name
  emergency_queue_url           = module.streaming.emergency_queue_url
  sns_owner_topic_arn           = module.streaming.sns_owner_topic_arn
  dynamodb_telemetry_table_name = module.storage.dynamodb_telemetry_table_name
  iot_role_arn                  = module.security.iot_core_role_arn
  kms_key_id                    = module.security.kms_key_id

  tags = local.common_tags
}

# ========================================
# STREAMING MODULE
# ========================================
module "streaming" {
  source = "./modules/streaming"

  project_name             = var.project_name
  environment              = var.environment
  kinesis_shard_count      = var.kinesis_shard_count
  kinesis_retention_period = var.kinesis_retention_period
  s3_data_lake_bucket      = module.storage.s3_data_lake_bucket
  kms_key_id               = module.security.kms_key_id
  firehose_role_arn        = module.security.firehose_role_arn
  firehose_role_name       = module.security.firehose_role_name
  enable_encryption        = var.enable_encryption

  tags = local.common_tags
}

# ========================================
# STORAGE MODULE
# ========================================
module "storage" {
  source = "./modules/storage"

  project_name               = var.project_name
  environment                = var.environment
  vpc_id                     = module.networking.vpc_id
  private_subnet_ids         = module.networking.private_subnet_ids
  db_subnet_group_name       = module.networking.db_subnet_group_name
  database_security_group_id = module.networking.database_security_group_id
  cache_security_group_id    = module.networking.cache_security_group_id

  # Aurora Configuration
  aurora_min_capacity          = var.aurora_min_capacity
  aurora_max_capacity          = var.aurora_max_capacity
  aurora_backup_retention_days = var.aurora_backup_retention_days

  # ElastiCache Configuration
  elasticache_node_type       = var.elasticache_node_type
  elasticache_num_cache_nodes = var.elasticache_num_cache_nodes

  # DynamoDB Configuration
  dynamodb_billing_mode = var.dynamodb_billing_mode
  dynamodb_ttl_days     = var.dynamodb_ttl_days

  # S3 Configuration
  s3_video_lifecycle_glacier_days = var.s3_video_lifecycle_glacier_days
  s3_logs_retention_days          = var.s3_logs_retention_days

  # Encryption
  kms_key_id        = module.security.kms_key_id
  enable_encryption = var.enable_encryption
  enable_timestream = var.enable_timestream

  tags = local.common_tags
}

# ========================================
# COMPUTE MODULE
# ========================================
module "compute" {
  source = "./modules/compute"

  project_name             = var.project_name
  environment              = var.environment
  vpc_id                   = module.networking.vpc_id
  private_subnet_ids       = module.networking.private_subnet_ids
  public_subnet_ids        = module.networking.public_subnet_ids
  alb_security_group_id    = module.networking.alb_security_group_id
  ecs_security_group_id    = module.networking.ecs_security_group_id
  lambda_security_group_id = module.networking.lambda_security_group_id

  # Lambda Configuration
  lambda_execution_role_arn    = module.security.lambda_execution_role_arn
  lambda_execution_role_name   = module.security.lambda_execution_role_name
  lambda_telemetry_memory      = var.lambda_telemetry_memory
  lambda_telemetry_timeout     = var.lambda_telemetry_timeout
  lambda_concurrent_executions = var.lambda_concurrent_executions

  # ECS Configuration
  ecs_task_execution_role_arn = module.security.ecs_task_execution_role_arn
  ecs_task_role_arn           = module.security.ecs_task_role_arn
  ecs_cpu                     = var.ecs_cpu
  ecs_memory                  = var.ecs_memory
  ecs_desired_count           = var.ecs_desired_count
  ecs_min_capacity            = var.ecs_min_capacity
  ecs_max_capacity            = var.ecs_max_capacity

  # Streaming Resources
  kinesis_stream_arn  = module.streaming.kinesis_stream_arn
  emergency_queue_arn = module.streaming.emergency_queue_arn
  emergency_queue_url = module.streaming.emergency_queue_url

  # Storage Resources
  dynamodb_telemetry_table_name             = module.storage.dynamodb_telemetry_table_name
  dynamodb_websocket_connections_table_name = module.storage.dynamodb_websocket_connections_table_name
  timestream_database_name                  = module.storage.timestream_database_name
  timestream_table_name                     = module.storage.timestream_table_name
  elasticache_endpoint                      = module.storage.elasticache_endpoint
  s3_logs_bucket                            = module.storage.s3_logs_bucket

  # Security Resources
  kms_key_id = module.security.kms_key_id

  # Workflows
  emergency_workflow_arn = null

  # Monitoring
  enable_xray        = var.enable_xray
  log_retention_days = var.cloudwatch_log_retention_days

  tags = local.common_tags
}

# ========================================
# API MODULE
# ========================================
module "api" {
  source = "./modules/api"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id

  # Compute Resources
  load_balancer_arn = module.compute.load_balancer_arn
  load_balancer_dns = module.compute.load_balancer_dns

  # Lambda Functions
  websocket_handler_arn = module.compute.websocket_handler_arn

  # Storage Resources
  dynamodb_telemetry_table_name = module.storage.dynamodb_telemetry_table_name

  # Security Resources
  cognito_user_pool_id  = module.security.cognito_user_pool_id
  cognito_user_pool_arn = module.security.cognito_user_pool_arn
  waf_web_acl_arn       = module.security.waf_web_acl_arn
  appsync_role_arn      = module.security.appsync_role_arn
  kms_key_id            = module.security.kms_key_id

  # Monitoring
  enable_xray        = var.enable_xray
  log_retention_days = var.cloudwatch_log_retention_days

  tags = local.common_tags
}

# ========================================
# WORKFLOWS MODULE
# ========================================
module "workflows" {
  source = "./modules/workflows"

  project_name = var.project_name
  environment  = var.environment

  # IAM Roles
  step_functions_role_arn = module.security.step_functions_role_arn

  # SNS Topics
  sns_authorities_topic_arn = module.streaming.sns_authorities_topic_arn
  sns_owner_topic_arn       = module.streaming.sns_owner_topic_arn
  sns_manager_topic_arn     = module.streaming.sns_manager_topic_arn

  # Storage Resources
  dynamodb_incidents_table_name = module.storage.dynamodb_incidents_table_name

  # Streaming Resources
  emergency_queue_url = module.streaming.emergency_queue_url

  # Security
  kms_key_id = module.security.kms_key_id

  # Monitoring
  log_retention_days = var.cloudwatch_log_retention_days

  tags = local.common_tags
}

# ========================================
# MONITORING MODULE
# ========================================
module "monitoring" {
  source = "./modules/monitoring"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  # Resources to monitor
  vpc_id                        = module.networking.vpc_id
  ecs_cluster_name              = module.compute.ecs_cluster_name
  kinesis_stream_name           = module.streaming.kinesis_stream_name
  dynamodb_telemetry_table_name = module.storage.dynamodb_telemetry_table_name
  aurora_cluster_id             = module.storage.aurora_cluster_id

  # SNS Topics for alerts
  sns_alarm_topic_arn = module.streaming.sns_alarm_topic_arn

  # Security
  kms_key_id = module.security.kms_key_id

  # Configuration
  enable_xray        = var.enable_xray
  enable_guardduty   = var.enable_guardduty
  log_retention_days = var.cloudwatch_log_retention_days

  tags = local.common_tags
}

# ========================================
# FRONTEND MODULE
# ========================================
module "frontend" {
  source = "./modules/frontend"

  project_name = var.project_name
  environment  = var.environment

  # CloudFront Configuration
  cloudfront_price_class = var.cloudfront_price_class
  domain_aliases         = var.frontend_domain_aliases
  acm_certificate_arn    = var.frontend_acm_certificate_arn

  # API Integration
  api_gateway_domain = module.api.api_gateway_rest_url

  # Features - Lambda@Edge removed
  enable_auto_invalidation = var.enable_cloudfront_auto_invalidation
  enable_logging           = true

  # Security
  waf_web_acl_id = module.security.waf_web_acl_id

  # Logging
  logs_bucket_domain_name = module.storage.s3_logs_bucket_domain_name
  log_retention_days      = var.cloudwatch_log_retention_days
  kms_key_id              = module.security.kms_key_id

  # DNS (optional)
  route53_zone_id = var.route53_zone_id

  # Geo Restrictions (optional)
  geo_restriction_type      = var.geo_restriction_type
  geo_restriction_locations = var.geo_restriction_locations

  tags = local.common_tags
}

