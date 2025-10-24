# Streaming Module - Kinesis, SQS, Firehose, SNS

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ========================================
# KINESIS DATA STREAM
# ========================================
resource "aws_kinesis_stream" "telemetry" {
  name             = "${local.name_prefix}-telemetry-stream"
  shard_count      = var.kinesis_shard_count
  retention_period = var.kinesis_retention_period

  shard_level_metrics = [
    "IncomingBytes",
    "IncomingRecords",
    "OutgoingBytes",
    "OutgoingRecords",
    "WriteProvisionedThroughputExceeded",
    "ReadProvisionedThroughputExceeded",
    "IteratorAgeMilliseconds"
  ]

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  encryption_type = var.enable_encryption ? "KMS" : "NONE"
  kms_key_id      = var.enable_encryption ? var.kms_key_id : null

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-telemetry-stream"
    }
  )
}

# ========================================
# KINESIS FIREHOSE - DATA LAKE
# ========================================
resource "aws_kinesis_firehose_delivery_stream" "data_lake" {
  name        = "${local.name_prefix}-data-lake-firehose"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.telemetry.arn
    role_arn           = var.firehose_role_arn
  }

  extended_s3_configuration {
    role_arn           = var.firehose_role_arn
    bucket_arn         = "arn:aws:s3:::${var.s3_data_lake_bucket}"
    prefix             = "telemetry/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    
    buffering_size     = 128
    buffering_interval = 300
    compression_format = "GZIP"

    data_format_conversion_configuration {
      input_format_configuration {
        deserializer {
          open_x_json_ser_de {}
        }
      }

      output_format_configuration {
        serializer {
          parquet_ser_de {}
        }
      }

      schema_configuration {
        database_name = "${local.name_prefix}_telemetry_db"
        table_name    = "telemetry"
        role_arn      = var.firehose_role_arn
      }
    }

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/${local.name_prefix}-data-lake"
      log_stream_name = "S3Delivery"
    }

    s3_backup_mode = "Disabled"
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-data-lake-firehose"
    }
  )
}

# ========================================
# SQS - EMERGENCY QUEUE (FIFO)
# ========================================
resource "aws_sqs_queue" "emergency_dlq" {
  name                       = "${local.name_prefix}-emergency-dlq.fifo"
  fifo_queue                 = true
  content_based_deduplication = true
  message_retention_seconds  = 1209600 # 14 days
  visibility_timeout_seconds = 30

  kms_master_key_id                 = var.kms_key_id
  kms_data_key_reuse_period_seconds = 300

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-emergency-dlq"
      Type = "DeadLetterQueue"
    }
  )
}

resource "aws_sqs_queue" "emergency" {
  name                       = "${local.name_prefix}-emergency-queue.fifo"
  fifo_queue                 = true
  content_based_deduplication = true
  
  # SLA: Process within 2 seconds
  visibility_timeout_seconds = 30
  message_retention_seconds  = 3600 # 1 hour
  receive_wait_time_seconds  = 0   # Short polling for low latency
  delay_seconds              = 0

  # High throughput configuration
  deduplication_scope   = "messageGroup"
  fifo_throughput_limit = "perMessageGroupId"

  kms_master_key_id                 = var.kms_key_id
  kms_data_key_reuse_period_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.emergency_dlq.arn
    maxReceiveCount     = 3
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-emergency-queue"
      Type = "EmergencyQueue"
      SLA  = "2s"
    }
  )
}

# ========================================
# SQS - NORMAL PROCESSING QUEUE
# ========================================
resource "aws_sqs_queue" "telemetry_dlq" {
  name                      = "${local.name_prefix}-telemetry-dlq"
  message_retention_seconds = 1209600 # 14 days

  kms_master_key_id                 = var.kms_key_id
  kms_data_key_reuse_period_seconds = 300

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-telemetry-dlq"
      Type = "DeadLetterQueue"
    }
  )
}

resource "aws_sqs_queue" "telemetry" {
  name                      = "${local.name_prefix}-telemetry-queue"
  visibility_timeout_seconds = 60
  message_retention_seconds = 3600 # 1 hour
  receive_wait_time_seconds = 20   # Long polling
  delay_seconds             = 0

  kms_master_key_id                 = var.kms_key_id
  kms_data_key_reuse_period_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.telemetry_dlq.arn
    maxReceiveCount     = 3
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-telemetry-queue"
      Type = "TelemetryQueue"
    }
  )
}

# ========================================
# SNS TOPICS
# ========================================

# Authorities Alert Topic
resource "aws_sns_topic" "authorities" {
  name              = "${local.name_prefix}-authorities-alerts"
  display_name      = "CCS Emergency Authorities Alerts"
  fifo_topic        = false
  kms_master_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-authorities-alerts"
      Type = "Emergency"
    }
  )
}

# Owner Alert Topic
resource "aws_sns_topic" "owner" {
  name              = "${local.name_prefix}-owner-alerts"
  display_name      = "CCS Vehicle Owner Alerts"
  fifo_topic        = false
  kms_master_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-owner-alerts"
      Type = "Emergency"
    }
  )
}

# Manager Notifications Topic
resource "aws_sns_topic" "manager" {
  name              = "${local.name_prefix}-manager-notifications"
  display_name      = "CCS Manager Notifications"
  fifo_topic        = false
  kms_master_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-manager-notifications"
      Type = "Business"
    }
  )
}

# Alarm Topic
resource "aws_sns_topic" "alarms" {
  name              = "${local.name_prefix}-alarms"
  display_name      = "CCS System Alarms"
  fifo_topic        = false
  kms_master_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-alarms"
      Type = "Monitoring"
    }
  )
}

# ========================================
# SNS SUBSCRIPTIONS (Example - SMS/Email)
# ========================================

# Example email subscription for alarms
# Uncomment and configure with actual email addresses
# resource "aws_sns_topic_subscription" "alarms_email" {
#   topic_arn = aws_sns_topic.alarms.arn
#   protocol  = "email"
#   endpoint  = "ops-team@ccs.co"
# }

# Example SMS subscription for authorities
# resource "aws_sns_topic_subscription" "authorities_sms" {
#   topic_arn = aws_sns_topic.authorities.arn
#   protocol  = "sms"
#   endpoint  = "+573001234567"
# }

# ========================================
# SNS TOPIC POLICIES
# ========================================

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    sid    = "AllowPublishFromServices"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com",
        "states.amazonaws.com",
        "events.amazonaws.com",
        "cloudwatch.amazonaws.com"
      ]
    }

    actions = [
      "SNS:Publish"
    ]

    resources = [
      aws_sns_topic.authorities.arn,
      aws_sns_topic.owner.arn,
      aws_sns_topic.manager.arn,
      aws_sns_topic.alarms.arn
    ]
  }
}

# NOTE: SNS topic policies commented out due to "Policy statement must apply to a single resource" error
# These can be added manually via AWS Console if needed
# resource "aws_sns_topic_policy" "authorities" {
#   arn    = aws_sns_topic.authorities.arn
#   policy = data.aws_iam_policy_document.sns_topic_policy.json
# }

# resource "aws_sns_topic_policy" "owner" {
#   arn    = aws_sns_topic.owner.arn
#   policy = data.aws_iam_policy_document.sns_topic_policy.json
# }

# resource "aws_sns_topic_policy" "manager" {
#   arn    = aws_sns_topic.manager.arn
#   policy = data.aws_iam_policy_document.sns_topic_policy.json
# }

# resource "aws_sns_topic_policy" "alarms" {
#   arn    = aws_sns_topic.alarms.arn
#   policy = data.aws_iam_policy_document.sns_topic_policy.json
# }

# ========================================
# SQS QUEUE POLICIES
# ========================================

data "aws_iam_policy_document" "emergency_queue_policy" {
  statement {
    sid    = "AllowIoTCoreToSendMessage"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["iot.amazonaws.com"]
    }

    actions = [
      "sqs:SendMessage"
    ]

    resources = [
      aws_sqs_queue.emergency.arn
    ]
  }

  statement {
    sid    = "AllowLambdaToReceiveMessage"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]

    resources = [
      aws_sqs_queue.emergency.arn
    ]
  }
}

resource "aws_sqs_queue_policy" "emergency" {
  queue_url = aws_sqs_queue.emergency.id
  policy    = data.aws_iam_policy_document.emergency_queue_policy.json
}

# ========================================
# CLOUDWATCH LOG GROUPS
# ========================================

resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${local.name_prefix}-data-lake"
  retention_in_days = var.log_retention_days

  kms_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-firehose-logs"
    }
  )
}

# ========================================
# KINESIS APPLICATION AUTO SCALING
# ========================================

# Auto Scaling Target
resource "aws_appautoscaling_target" "kinesis" {
  max_capacity       = 50
  min_capacity       = var.kinesis_shard_count
  resource_id        = "stream/${aws_kinesis_stream.telemetry.name}"
  scalable_dimension = "kinesis:stream:ReadCapacityUnits"
  service_namespace  = "kinesis"
}

# Scale Up Policy
resource "aws_appautoscaling_policy" "kinesis_scale_up" {
  name               = "${local.name_prefix}-kinesis-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.kinesis.resource_id
  scalable_dimension = aws_appautoscaling_target.kinesis.scalable_dimension
  service_namespace  = aws_appautoscaling_target.kinesis.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "KinesisStreamIncomingRecords"
    }

    target_value       = 1000.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ========================================
# EVENTBRIDGE RULES (Optional)
# ========================================

# Rule to route high-priority events
resource "aws_cloudwatch_event_rule" "high_priority_telemetry" {
  name        = "${local.name_prefix}-high-priority-telemetry"
  description = "Route high-priority telemetry events"

  event_pattern = jsonencode({
    source      = ["ccs.telemetry"]
    detail-type = ["Vehicle Telemetry"]
    detail = {
      priority = ["high"]
    }
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-high-priority-telemetry"
    }
  )
}

resource "aws_cloudwatch_event_target" "high_priority_to_kinesis" {
  rule      = aws_cloudwatch_event_rule.high_priority_telemetry.name
  target_id = "SendToKinesis"
  arn       = aws_kinesis_stream.telemetry.arn

  role_arn = var.eventbridge_role_arn
}

