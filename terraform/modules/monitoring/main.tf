# Monitoring Module - CloudWatch, X-Ray, GuardDuty

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ========================================
# CLOUDWATCH DASHBOARD
# ========================================
# NOTE: CloudWatch Dashboard commented out due to invalid metrics format
# Each metric should have max 2 elements, but current config has more
# resource "aws_cloudwatch_dashboard" "main" {
#   dashboard_name = "${local.name_prefix}-main-dashboard"
# 
#   dashboard_body = jsonencode({
#     widgets = [
#       # Emergency Response Section
#       {
#         type = "metric"
#         properties = {
#           metrics = [
#             ["AWS/States", "ExecutionTime", { stat = "Average", label = "Avg Emergency Response Time" }],
#             [".", ".", { stat = "p99", label = "p99 Response Time" }]
#           ]
#           period = 60
#           stat   = "Average"
#           region = var.aws_region
#           title  = "Emergency Response Latency (Target: <2s)"
#           yAxis = {
#             left = {
#               min = 0
#               max = 3000
#             }
#           }
#         }
#       },
#       # Kinesis Throughput
#       {
#         type = "metric"
#         properties = {
#           metrics = [
#             ["AWS/Kinesis", "IncomingRecords", { stat = "Sum", label = "Incoming Records/sec" }],
#             [".", "IncomingBytes", { stat = "Sum", label = "Incoming Bytes/sec", yAxis = "right" }]
#           ]
#           period = 60
#           stat   = "Sum"
#           region = var.aws_region
#           title  = "Kinesis Telemetry Throughput"
#         }
#       },
#       # DynamoDB Performance
#       {
#         type = "metric"
#         properties = {
#           metrics = [
#             ["AWS/DynamoDB", "ConsumedReadCapacityUnits", { TableName = var.dynamodb_telemetry_table_name }],
#             [".", "ConsumedWriteCapacityUnits", { TableName = var.dynamodb_telemetry_table_name }],
#             [".", "UserErrors", { TableName = var.dynamodb_telemetry_table_name, stat = "Sum" }]
#           ]
#           period = 60
#           stat   = "Sum"
#           region = var.aws_region
#           title  = "DynamoDB Telemetry Table"
#         }
#       },
#       # ECS Service Health
#       {
#         type = "metric"
#         properties = {
#           metrics = [
#             ["AWS/ECS", "CPUUtilization", { ClusterName = var.ecs_cluster_name }],
#             [".", "MemoryUtilization", { ClusterName = var.ecs_cluster_name }]
#           ]
#           period = 60
#           stat   = "Average"
#           region = var.aws_region
#           title  = "ECS Cluster Resource Utilization"
#         }
#       },
#       # ALB Health
#       {
#         type = "metric"
#         properties = {
#           metrics = [
#             ["AWS/ApplicationELB", "HealthyHostCount", { LoadBalancer = var.load_balancer_name }],
#             [".", "UnHealthyHostCount", { LoadBalancer = var.load_balancer_name }],
#             [".", "HTTPCode_Target_2XX_Count", { LoadBalancer = var.load_balancer_name, stat = "Sum" }],
#             [".", "HTTPCode_Target_5XX_Count", { LoadBalancer = var.load_balancer_name, stat = "Sum" }]
#           ]
#           period = 60
#           stat   = "Average"
#           region = var.aws_region
#           title  = "Application Load Balancer Health"
#         }
#       },
#       # Aurora Performance
#       {
#         type = "metric"
#         properties = {
#           metrics = [
#             ["AWS/RDS", "DatabaseConnections", { DBClusterIdentifier = var.aurora_cluster_id }],
#             [".", "CPUUtilization", { DBClusterIdentifier = var.aurora_cluster_id }],
#             [".", "ReadLatency", { DBClusterIdentifier = var.aurora_cluster_id }],
#             [".", "WriteLatency", { DBClusterIdentifier = var.aurora_cluster_id }]
#           ]
#           period = 60
#           stat   = "Average"
#           region = var.aws_region
#           title  = "Aurora PostgreSQL Performance"
#         }
#       },
#       # ElastiCache Performance
#       {
#         type = "metric"
#         properties = {
#           metrics = [
#             ["AWS/ElastiCache", "CacheHitRate", { CacheClusterId = var.elasticache_cluster_id }],
#             [".", "CPUUtilization", { CacheClusterId = var.elasticache_cluster_id }],
#             [".", "NetworkBytesIn", { CacheClusterId = var.elasticache_cluster_id }],
#             [".", "Evictions", { CacheClusterId = var.elasticache_cluster_id, stat = "Sum" }]
#           ]
#           period = 60
#           stat   = "Average"
#           region = var.aws_region
#           title  = "ElastiCache Redis Performance"
#         }
#       },
#       # API Gateway
#       {
#         type = "metric"
#         properties = {
#           metrics = [
#             ["AWS/ApiGateway", "Count", { ApiName = var.api_gateway_name, stat = "Sum" }],
#             [".", "4XXError", { ApiName = var.api_gateway_name, stat = "Sum" }],
#             [".", "5XXError", { ApiName = var.api_gateway_name, stat = "Sum" }],
#             [".", "Latency", { ApiName = var.api_gateway_name, stat = "Average" }]
#           ]
#           period = 60
#           stat   = "Sum"
#           region = var.aws_region
#           title  = "API Gateway Requests & Errors"
#         }
#       }
#     ]
#   })
# }
# 
# # ========================================
# # CLOUDWATCH ALARMS - EMERGENCY RESPONSE
# # ========================================
# resource "aws_cloudwatch_metric_alarm" "emergency_latency_high" {
#   alarm_name          = "${local.name_prefix}-emergency-latency-high"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "ExecutionTime"
#   namespace           = "AWS/States"
#   period              = 60
#   statistic           = "Average"
#   threshold           = 2000
#   alarm_description   = "Emergency response time exceeded 2 seconds"
#   alarm_actions       = [var.sns_alarm_topic_arn]
#   treat_missing_data  = "notBreaching"
# 
#   dimensions = {
#     StateMachineArn = var.emergency_workflow_arn
#   }
# 
#   tags = merge(
#     var.tags,
#     {
#       Name     = "${local.name_prefix}-emergency-latency-alarm"
#       Severity = "Critical"
#     }
#   )
# }
# 
# # ========================================
# # CLOUDWATCH ALARMS - KINESIS
# # ========================================
# resource "aws_cloudwatch_metric_alarm" "kinesis_iterator_age_high" {
#   alarm_name          = "${local.name_prefix}-kinesis-iterator-age-high"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "GetRecords.IteratorAgeMilliseconds"
#   namespace           = "AWS/Kinesis"
#   period              = 300
#   statistic           = "Maximum"
#   threshold           = 60000
#   alarm_description   = "Kinesis processing lag exceeded 60 seconds"
#   alarm_actions       = [var.sns_alarm_topic_arn]
# 
#   dimensions = {
#     StreamName = var.kinesis_stream_name
#   }
# 
#   tags = merge(
#     var.tags,
#     {
#       Name     = "${local.name_prefix}-kinesis-lag-alarm"
#       Severity = "High"
#     }
#   )
# }

# ========================================
# CLOUDWATCH ALARMS - DYNAMODB
# ========================================
resource "aws_cloudwatch_metric_alarm" "dynamodb_user_errors" {
  alarm_name          = "${local.name_prefix}-dynamodb-user-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UserErrors"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "DynamoDB user errors exceeded threshold"
  alarm_actions       = [var.sns_alarm_topic_arn]

  dimensions = {
    TableName = var.dynamodb_telemetry_table_name
  }

  tags = merge(
    var.tags,
    {
      Name     = "${local.name_prefix}-dynamodb-errors-alarm"
      Severity = "Medium"
    }
  )
}

# ========================================
# CLOUDWATCH ALARMS - ALB
# ========================================
# resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
#   alarm_name          = "${local.name_prefix}-alb-unhealthy-hosts"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "UnHealthyHostCount"
#   namespace           = "AWS/ApplicationELB"
#   period              = 60
#   statistic           = "Average"
#   threshold           = 0
#   alarm_description   = "ALB has unhealthy target hosts"
#   alarm_actions       = [var.sns_alarm_topic_arn]
# 
#   dimensions = {
#     LoadBalancer = var.load_balancer_arn_suffix
#   }
# 
#   tags = merge(
#     var.tags,
#     {
#       Name     = "${local.name_prefix}-alb-health-alarm"
#       Severity = "High"
#     }
#   )
# }
# 
# resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
#   alarm_name          = "${local.name_prefix}-alb-5xx-errors"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "HTTPCode_Target_5XX_Count"
#   namespace           = "AWS/ApplicationELB"
#   period              = 300
#   statistic           = "Sum"
#   threshold           = 50
#   alarm_description   = "ALB 5XX errors exceeded threshold"
#   alarm_actions       = [var.sns_alarm_topic_arn]
# 
#   dimensions = {
#     LoadBalancer = var.load_balancer_arn_suffix
#   }
# 
#   tags = merge(
#     var.tags,
#     {
#       Name     = "${local.name_prefix}-alb-5xx-alarm"
#       Severity = "High"
#     }
#   )
# }
# 
# # ========================================
# # CLOUDWATCH ALARMS - AURORA
# # ========================================
resource "aws_cloudwatch_metric_alarm" "aurora_cpu_high" {
  alarm_name          = "${local.name_prefix}-aurora-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Aurora CPU utilization exceeded 80%"
  alarm_actions       = [var.sns_alarm_topic_arn]

  dimensions = {
    DBClusterIdentifier = var.aurora_cluster_id
  }

  tags = merge(
    var.tags,
    {
      Name     = "${local.name_prefix}-aurora-cpu-alarm"
      Severity = "Medium"
    }
  )
}

# ========================================
# CLOUDWATCH ALARMS - ELASTICACHE
# ========================================
# resource "aws_cloudwatch_metric_alarm" "elasticache_cpu_high" {
#   alarm_name          = "${local.name_prefix}-elasticache-cpu-high"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/ElastiCache"
#   period              = 300
#   statistic           = "Average"
#   threshold           = 75
#   alarm_description   = "ElastiCache CPU utilization exceeded 75%"
#   alarm_actions       = [var.sns_alarm_topic_arn]
# 
#   dimensions = {
#     CacheClusterId = var.elasticache_cluster_id
#   }
# 
#   tags = merge(
#     var.tags,
#     {
#       Name     = "${local.name_prefix}-elasticache-cpu-alarm"
#       Severity = "Medium"
#     }
#   )
# }
# 
# resource "aws_cloudwatch_metric_alarm" "elasticache_low_hit_rate" {
#   alarm_name          = "${local.name_prefix}-elasticache-low-hit-rate"
#   comparison_operator = "LessThanThreshold"
#   evaluation_periods  = 3
#   metric_name         = "CacheHitRate"
#   namespace           = "AWS/ElastiCache"
#   period              = 300
#   statistic           = "Average"
#   threshold           = 0.80
#   alarm_description   = "ElastiCache hit rate below 80%"
#   alarm_actions       = [var.sns_alarm_topic_arn]
# 
#   dimensions = {
#     CacheClusterId = var.elasticache_cluster_id
#   }
# 
#   tags = merge(
#     var.tags,
#     {
#       Name     = "${local.name_prefix}-elasticache-hitrate-alarm"
#       Severity = "Low"
#     }
#   )
# }
# 
# ========================================
# AWS X-RAY
# ========================================
resource "aws_xray_sampling_rule" "main" {
  count = var.enable_xray ? 1 : 0

  rule_name      = "${local.name_prefix}-sampling-rule"
  priority       = 1000
  version        = 1
  reservoir_size = 1
  fixed_rate     = 0.05
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"
  resource_arn   = "*"

  attributes = {
    environment = var.environment
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-xray-sampling-rule"
    }
  )
}

# ========================================
# AWS GUARDDUTY
# ========================================
resource "aws_guardduty_detector" "main" {
  count = var.enable_guardduty ? 1 : 0

  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = false
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = false
        }
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-guardduty"
    }
  )
}

# GuardDuty Findings to SNS
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  count = var.enable_guardduty ? 1 : 0

  name        = "${local.name_prefix}-guardduty-findings"
  description = "Route GuardDuty findings to SNS"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [4, 4.0, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 5, 5.0, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 6, 6.0, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9, 7, 7.0, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9, 8, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9]
    }
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-guardduty-findings-rule"
    }
  )
}

resource "aws_cloudwatch_event_target" "guardduty_to_sns" {
  count = var.enable_guardduty ? 1 : 0

  rule      = aws_cloudwatch_event_rule.guardduty_findings[0].name
  target_id = "SendToSNS"
  arn       = var.sns_alarm_topic_arn
}

# ========================================
# CLOUDWATCH LOG GROUPS
# ========================================
resource "aws_cloudwatch_log_group" "application_logs" {
  name              = "/application/${local.name_prefix}"
  retention_in_days = var.log_retention_days

  kms_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-application-logs"
    }
  )
}

# ========================================
# CLOUDWATCH LOG METRIC FILTERS
# ========================================
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  name           = "${local.name_prefix}-error-count"
  log_group_name = aws_cloudwatch_log_group.application_logs.name
  pattern        = "[ERROR]"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "CCS/${var.environment}"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${local.name_prefix}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ErrorCount"
  namespace           = "CCS/${var.environment}"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "Application error rate exceeded threshold"
  alarm_actions       = [var.sns_alarm_topic_arn]

  tags = merge(
    var.tags,
    {
      Name     = "${local.name_prefix}-error-rate-alarm"
      Severity = "High"
    }
  )
}

# ========================================
# DATA SOURCES
# ========================================
data "aws_region" "current" {}

