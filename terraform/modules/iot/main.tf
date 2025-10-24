# IoT Module - AWS IoT Core, Thing Registry, Rules Engine

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ========================================
# IOT THING TYPE
# ========================================
resource "aws_iot_thing_type" "vehicle" {
  name = "${local.name_prefix}-vehicle-thing-type"

  properties {
    description           = "CCS Vehicle IoT Device"
    searchable_attributes = ["vehicleId", "region", "fleetId"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-vehicle-thing-type"
    }
  )
}

# ========================================
# IOT POLICY - Vehicle Devices
# ========================================
resource "aws_iot_policy" "vehicle" {
  name = "${local.name_prefix}-vehicle-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iot:Connect"
        ]
        Resource = [
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:client/$${iot:Connection.Thing.ThingName}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Publish"
        ]
        Resource = [
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/vehicle/$${iot:Connection.Thing.ThingName}/telemetry",
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/vehicle/$${iot:Connection.Thing.ThingName}/emergency",
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/vehicle/$${iot:Connection.Thing.ThingName}/video-metadata"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Subscribe"
        ]
        Resource = [
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topicfilter/vehicle/$${iot:Connection.Thing.ThingName}/commands"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Receive"
        ]
        Resource = [
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/vehicle/$${iot:Connection.Thing.ThingName}/commands"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iot:UpdateThingShadow",
          "iot:GetThingShadow"
        ]
        Resource = [
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:thing/$${iot:Connection.Thing.ThingName}"
        ]
      }
    ]
  })
}

# ========================================
# IOT RULE - EMERGENCY EVENTS (Fast Lane)
# ========================================
# NOTE: Commented out due to SQL syntax error with IN clause
# Can be created manually via AWS Console with corrected SQL
# resource "aws_iot_topic_rule" "emergency" {
#   name        = replace("${local.name_prefix}_emergency_rule", "-", "_")
#   description = "Route emergency events to SQS FIFO for <2s processing"
#   enabled     = true
#   sql         = "SELECT *, topic(2) as vehicleId, timestamp() as eventTimestamp FROM 'vehicle/+/emergency' WHERE type IN ('panic_button', 'accident', 'hijack', 'critical_anomaly')"
#   sql_version = "2016-03-23"

#   sqs {
#     queue_url  = var.emergency_queue_url
#     role_arn   = var.iot_role_arn
#     use_base64 = false
#   }

#   error_action {
#     cloudwatch_logs {
#       log_group_name = aws_cloudwatch_log_group.iot_errors.name
#       role_arn       = var.iot_role_arn
#     }
#   }

#   tags = merge(
#     var.tags,
#     {
#       Name = "${local.name_prefix}-emergency-rule"
#       Lane = "Fast"
#       SLA  = "2s"
#     }
#   )
# }

# ========================================
# IOT RULE - NORMAL TELEMETRY (Normal Lane)
# ========================================
resource "aws_iot_topic_rule" "telemetry" {
  name        = replace("${local.name_prefix}_telemetry_rule", "-", "_")
  description = "Route normal telemetry to Kinesis for batch processing"
  enabled     = true
  sql         = "SELECT *, topic(2) as vehicleId, timestamp() as eventTimestamp FROM 'vehicle/+/telemetry'"
  sql_version = "2016-03-23"

  kinesis {
    stream_name  = var.kinesis_stream_name
    role_arn     = var.iot_role_arn
    partition_key = "$${vehicleId}"
  }

  error_action {
    cloudwatch_logs {
      log_group_name = aws_cloudwatch_log_group.iot_errors.name
      role_arn       = var.iot_role_arn
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-telemetry-rule"
      Lane = "Normal"
    }
  )
}

# ========================================
# IOT RULE - VIDEO METADATA
# ========================================
resource "aws_iot_topic_rule" "video_metadata" {
  name        = replace("${local.name_prefix}_video_metadata_rule", "-", "_")
  description = "Route video metadata to DynamoDB for indexing"
  enabled     = true
  sql         = "SELECT *, topic(2) as vehicleId, timestamp() as eventTimestamp FROM 'vehicle/+/video-metadata'"
  sql_version = "2016-03-23"

  dynamodb {
    table_name = var.dynamodb_telemetry_table_name
    role_arn   = var.iot_role_arn
    hash_key_field  = "vehicle_id"
    hash_key_value  = "$${vehicleId}"
    range_key_field = "timestamp"
    range_key_value = "$${eventTimestamp}"
    hash_key_type   = "STRING"
    range_key_type  = "NUMBER"
  }

  error_action {
    cloudwatch_logs {
      log_group_name = aws_cloudwatch_log_group.iot_errors.name
      role_arn       = var.iot_role_arn
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-video-metadata-rule"
    }
  )
}

# ========================================
# IOT RULE - HIGH TEMPERATURE ALERT
# ========================================
resource "aws_iot_topic_rule" "high_temperature" {
  name        = replace("${local.name_prefix}_high_temperature_rule", "-", "_")
  description = "Alert on high cargo temperature"
  enabled     = true
  sql         = "SELECT *, topic(2) as vehicleId FROM 'vehicle/+/telemetry' WHERE cargo_temperature > 30"
  sql_version = "2016-03-23"

  sns {
    target_arn = var.sns_owner_topic_arn
    role_arn   = var.iot_role_arn
    message_format = "JSON"
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-high-temperature-rule"
      Type = "Alert"
    }
  )
}

# ========================================
# IOT RULE - SPEEDING ALERT
# ========================================
resource "aws_iot_topic_rule" "speeding" {
  name        = replace("${local.name_prefix}_speeding_rule", "-", "_")
  description = "Alert on excessive speed"
  enabled     = true
  sql         = "SELECT *, topic(2) as vehicleId FROM 'vehicle/+/telemetry' WHERE speed > 120"
  sql_version = "2016-03-23"

  sns {
    target_arn = var.sns_owner_topic_arn
    role_arn   = var.iot_role_arn
    message_format = "JSON"
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-speeding-rule"
      Type = "Alert"
    }
  )
}

# ========================================
# IOT RULE - LONG IDLE DETECTION
# ========================================
# NOTE: Commented out due to missing Lambda ARN
# Enable after Lambda is created and ARN is passed correctly
# resource "aws_iot_topic_rule" "long_idle" {
#   name        = replace("${local.name_prefix}_long_idle_rule", "-", "_")
#   description = "Detect vehicles idle for extended periods"
#   enabled     = true
#   sql         = "SELECT *, topic(2) as vehicleId FROM 'vehicle/+/telemetry' WHERE speed = 0 AND engine_status = 'on'"
#   sql_version = "2016-03-23"

#   lambda {
#     function_arn = var.anomaly_detector_lambda_arn
#   }

#   tags = merge(
#     var.tags,
#     {
#       Name = "${local.name_prefix}-long-idle-rule"
#       Type = "Anomaly"
#     }
#   )
# }

# ========================================
# IOT CERTIFICATE - Example for testing
# ========================================
resource "aws_iot_certificate" "test_vehicle" {
  count  = var.environment == "dev" ? 1 : 0
  active = true
}

resource "aws_iot_thing" "test_vehicle" {
  count          = var.environment == "dev" ? 1 : 0
  name           = "${local.name_prefix}-test-vehicle-001"
  thing_type_name = aws_iot_thing_type.vehicle.name

  attributes = {
    vehicleId = "TEST-001"
    region    = "us-east-1"
    fleetId   = "FLEET-TEST"
    model     = "TestModel"
  }
}

resource "aws_iot_thing_principal_attachment" "test_vehicle" {
  count     = var.environment == "dev" ? 1 : 0
  principal = aws_iot_certificate.test_vehicle[0].arn
  thing     = aws_iot_thing.test_vehicle[0].name
}

resource "aws_iot_policy_attachment" "test_vehicle" {
  count  = var.environment == "dev" ? 1 : 0
  policy = aws_iot_policy.vehicle.name
  target = aws_iot_certificate.test_vehicle[0].arn
}

# ========================================
# CLOUDWATCH LOG GROUP FOR IOT ERRORS
# ========================================
resource "aws_cloudwatch_log_group" "iot_errors" {
  name              = "/aws/iot/${local.name_prefix}/errors"
  retention_in_days = var.log_retention_days

  kms_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-iot-errors"
    }
  )
}

# ========================================
# IOT LOGGING
# ========================================
resource "aws_iot_logging_options" "main" {
  default_log_level = var.environment == "prod" ? "ERROR" : "INFO"

  role_arn = var.iot_role_arn
}

# ========================================
# IOT FLEET INDEXING
# ========================================
resource "aws_iot_indexing_configuration" "main" {
  thing_indexing_configuration {
    thing_indexing_mode              = "REGISTRY_AND_SHADOW"
    thing_connectivity_indexing_mode = "STATUS"
    device_defender_indexing_mode    = "VIOLATIONS"

    custom_field {
      name = "attributes.vehicleId"
      type = "String"
    }

    custom_field {
      name = "attributes.region"
      type = "String"
    }

    custom_field {
      name = "attributes.fleetId"
      type = "String"
    }
  }
}

# ========================================
# IOT TOPIC RULE DESTINATION (for HTTP endpoints)
# ========================================
# Uncomment if you need HTTP endpoint destinations
# resource "aws_iot_topic_rule_destination" "authorities_webhook" {
#   vpc_configuration {
#     subnet_ids         = var.private_subnet_ids
#     security_group_ids = [var.iot_security_group_id]
#     vpc_id            = var.vpc_id
#     role_arn          = var.iot_role_arn
#   }
# }

# ========================================
# DATA SOURCES
# ========================================
data "aws_iot_endpoint" "main" {
  endpoint_type = "iot:Data-ATS"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

