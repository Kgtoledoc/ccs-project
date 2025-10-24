# Storage Module - DynamoDB, RDS Aurora, S3, ElastiCache, Timestream

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ========================================
# DYNAMODB TABLES
# ========================================

# Telemetry Table
resource "aws_dynamodb_table" "telemetry" {
  name           = "${local.name_prefix}-telemetry"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "vehicle_id"
  range_key      = "timestamp"

  attribute {
    name = "vehicle_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  server_side_encryption {
    enabled     = var.enable_encryption
    kms_key_arn = var.enable_encryption ? "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}" : null
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-telemetry"
    }
  )
}

# Incidents Table
resource "aws_dynamodb_table" "incidents" {
  name           = "${local.name_prefix}-incidents"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "incident_id"
  range_key      = "timestamp"

  attribute {
    name = "incident_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "vehicle_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "VehicleIndex"
    hash_key        = "vehicle_id"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  server_side_encryption {
    enabled     = var.enable_encryption
    kms_key_arn = var.enable_encryption ? "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}" : null
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-incidents"
    }
  )
}

# Alerts Configuration Table
resource "aws_dynamodb_table" "alerts_config" {
  name           = "${local.name_prefix}-alerts-config"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user_id"
  range_key      = "alert_type"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "alert_type"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = var.enable_encryption
    kms_key_arn = var.enable_encryption ? "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}" : null
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-alerts-config"
    }
  )
}

# WebSocket Connections Table
resource "aws_dynamodb_table" "websocket_connections" {
  name           = "${local.name_prefix}-websocket-connections"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "connection_id"

  attribute {
    name = "connection_id"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  server_side_encryption {
    enabled     = var.enable_encryption
    kms_key_arn = var.enable_encryption ? "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}" : null
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-websocket-connections"
    }
  )
}

# ========================================
# RDS POSTGRESQL SIMPLE (RÁPIDO PARA TESTING)
# ========================================
# Cambiado de Aurora Serverless v2 a RDS PostgreSQL para deployment más rápido

resource "aws_db_instance" "main" {
  identifier     = "${local.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t3.micro"  # Pequeño y rápido de crear
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = false  # Deshabilitado para simplificar

  db_name  = replace("${local.name_prefix}_db", "-", "_")
  username = "ccsadmin"
  password = random_password.db_password.result
  
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.database_security_group_id]
  publicly_accessible    = false
  
  backup_retention_period = var.aurora_backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"
  
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn
  
  skip_final_snapshot = true  # Para facilitar testing
  deletion_protection = false  # Para facilitar testing
  apply_immediately   = true

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-postgres"
      Type = "RDS-Simple-Testing"
    }
  )
}

resource "random_password" "db_password" {
  length  = 32
  special = false  # Evita caracteres inválidos para RDS: /, @, ", espacio
}

# RDS Monitoring Role
resource "aws_iam_role" "rds_monitoring" {
  name = "${local.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-rds-monitoring-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ========================================
# ELASTICACHE REDIS
# ========================================

resource "aws_elasticache_subnet_group" "main" {
  name       = "${local.name_prefix}-elasticache-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-elasticache-subnet-group"
    }
  )
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${local.name_prefix}-redis"
  description          = "Redis cache for ${local.name_prefix}"
  
  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.elasticache_node_type
  num_cache_clusters   = var.elasticache_num_cache_nodes
  parameter_group_name = aws_elasticache_parameter_group.main.name
  port                 = 6379

  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [var.cache_security_group_id]

  automatic_failover_enabled = true
  multi_az_enabled          = true

  at_rest_encryption_enabled = var.enable_encryption
  transit_encryption_enabled = var.enable_encryption
  auth_token                 = var.enable_encryption ? random_password.redis_auth.result : null
  kms_key_id                 = var.enable_encryption ? var.kms_key_id : null

  snapshot_retention_limit = 5
  snapshot_window         = "03:00-05:00"
  maintenance_window      = "sun:05:00-sun:07:00"

  auto_minor_version_upgrade = true

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.elasticache.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-redis"
    }
  )
}

resource "aws_elasticache_parameter_group" "main" {
  name   = "${local.name_prefix}-redis-params"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-redis-params"
    }
  )
}

resource "random_password" "redis_auth" {
  length  = 32
  special = false
}

resource "aws_cloudwatch_log_group" "elasticache" {
  name              = "/aws/elasticache/${local.name_prefix}-redis"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-elasticache-logs"
    }
  )
}

# ========================================
# S3 BUCKETS
# ========================================

# Data Lake Bucket
resource "aws_s3_bucket" "data_lake" {
  bucket = "${local.name_prefix}-data-lake"

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-data-lake"
      Type = "DataLake"
    }
  )
}

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_encryption ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_encryption ? var.kms_key_id : null
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    id     = "intelligent-tiering"
    status = "Enabled"
    
    filter {}

    transition {
      days          = 90
      storage_class = "INTELLIGENT_TIERING"
    }

    transition {
      days          = 180
      storage_class = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Videos Bucket
resource "aws_s3_bucket" "videos" {
  bucket = "${local.name_prefix}-videos"

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-videos"
      Type = "Videos"
    }
  )
}

resource "aws_s3_bucket_versioning" "videos" {
  bucket = aws_s3_bucket.videos.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "videos" {
  bucket = aws_s3_bucket.videos.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_encryption ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_encryption ? var.kms_key_id : null
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "videos" {
  bucket = aws_s3_bucket.videos.id

  rule {
    id     = "archive-videos"
    status = "Enabled"
    
    filter {}

    transition {
      days          = var.s3_video_lifecycle_glacier_days
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

resource "aws_s3_bucket_public_access_block" "videos" {
  bucket = aws_s3_bucket.videos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Logs Bucket
resource "aws_s3_bucket" "logs" {
  bucket = "${local.name_prefix}-logs"

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-logs"
      Type = "Logs"
    }
  )
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"
    
    filter {}

    expiration {
      days = var.s3_logs_retention_days
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ========================================
# AMAZON TIMESTREAM
# ========================================

resource "aws_timestreamwrite_database" "main" {
  count = var.enable_timestream ? 1 : 0
  
  database_name = replace("${local.name_prefix}_metrics", "-", "_")

  kms_key_id = var.enable_encryption ? "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}" : null

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-metrics-db"
    }
  )
}

resource "aws_timestreamwrite_table" "vehicle_metrics" {
  count = var.enable_timestream ? 1 : 0
  
  database_name = aws_timestreamwrite_database.main[0].database_name
  table_name    = "vehicle_metrics"

  retention_properties {
    magnetic_store_retention_period_in_days = 365
    memory_store_retention_period_in_hours  = 24
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-vehicle-metrics"
    }
  )
}

# ========================================
# DATA SOURCES
# ========================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

