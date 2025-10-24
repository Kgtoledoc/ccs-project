# Compute Module - Lambda Functions, ECS Fargate, ALB

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ========================================
# DATA SOURCES FOR LAMBDA PACKAGING
# ========================================
data "archive_file" "telemetry_processor" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/telemetry_processor"
  output_path = "${path.module}/.terraform/telemetry_processor.zip"
}

data "archive_file" "emergency_orchestrator" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/emergency_orchestrator"
  output_path = "${path.module}/.terraform/emergency_orchestrator.zip"
}

data "archive_file" "anomaly_detector" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/anomaly_detector"
  output_path = "${path.module}/.terraform/anomaly_detector.zip"
}

data "archive_file" "websocket_handler" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/websocket_handler"
  output_path = "${path.module}/.terraform/websocket_handler.zip"
}

# ========================================
# LAMBDA FUNCTIONS
# ========================================

# Telemetry Processor
resource "aws_lambda_function" "telemetry_processor" {
  filename         = data.archive_file.telemetry_processor.output_path
  function_name    = "${local.name_prefix}-telemetry-processor"
  role             = var.lambda_execution_role_arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.telemetry_processor.output_base64sha256
  runtime          = "nodejs18.x"
  timeout          = var.lambda_telemetry_timeout
  memory_size      = var.lambda_telemetry_memory

  reserved_concurrent_executions = var.lambda_concurrent_executions

  environment {
    variables = {
      DYNAMODB_TELEMETRY_TABLE = var.dynamodb_telemetry_table_name
      TIMESTREAM_DATABASE      = var.timestream_database_name
      TIMESTREAM_TABLE         = var.timestream_table_name
      ENVIRONMENT              = var.environment
    }
  }

  # VPC removed - Lambda accesses AWS services via AWS internal network
  # Benefits: 10-100x faster cold start, no ENI issues, $50/month savings

  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-telemetry-processor"
    }
  )
}

# Kinesis Event Source Mapping
resource "aws_lambda_event_source_mapping" "kinesis_telemetry" {
  event_source_arn  = var.kinesis_stream_arn
  function_name     = aws_lambda_function.telemetry_processor.arn
  starting_position = "LATEST"
  batch_size        = 100
  maximum_batching_window_in_seconds = 60

  enabled = true
}

# IAM Policy for Lambda to read from Kinesis and SQS
resource "aws_iam_role_policy" "lambda_kinesis" {
  name = "${local.name_prefix}-lambda-kinesis-policy"
  role = var.lambda_execution_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:ListShards",
          "kinesis:ListStreams"
        ]
        Resource = var.kinesis_stream_arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.emergency_queue_arn
      }
    ]
  })
}

# Emergency Orchestrator
resource "aws_lambda_function" "emergency_orchestrator" {
  filename         = data.archive_file.emergency_orchestrator.output_path
  function_name    = "${local.name_prefix}-emergency-orchestrator"
  role             = var.lambda_execution_role_arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.emergency_orchestrator.output_base64sha256
  runtime          = "nodejs18.x"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      # EMERGENCY_WORKFLOW_ARN = var.emergency_workflow_arn
      ENVIRONMENT            = var.environment
    }
  }

  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-emergency-orchestrator"
    }
  )
}

# SQS Event Source Mapping for Emergency
resource "aws_lambda_event_source_mapping" "sqs_emergency" {
  event_source_arn = var.emergency_queue_arn
  function_name    = aws_lambda_function.emergency_orchestrator.arn
  batch_size       = 1
  enabled          = true
}

# Anomaly Detector
resource "aws_lambda_function" "anomaly_detector" {
  filename         = data.archive_file.anomaly_detector.output_path
  function_name    = "${local.name_prefix}-anomaly-detector"
  role             = var.lambda_execution_role_arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.anomaly_detector.output_base64sha256
  runtime          = "nodejs18.x"
  timeout          = 15
  memory_size      = 256

  environment {
    variables = {
      EMERGENCY_QUEUE_URL = var.emergency_queue_url
      ENVIRONMENT         = var.environment
    }
  }

  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-anomaly-detector"
    }
  )
}

# WebSocket Handler
resource "aws_lambda_function" "websocket_handler" {
  filename         = data.archive_file.websocket_handler.output_path
  function_name    = "${local.name_prefix}-websocket-handler"
  role             = var.lambda_execution_role_arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.websocket_handler.output_base64sha256
  runtime          = "nodejs18.x"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      CONNECTIONS_TABLE   = var.dynamodb_websocket_connections_table_name
      WEBSOCKET_ENDPOINT  = var.websocket_endpoint
      ENVIRONMENT         = var.environment
    }
  }

  # VPC removed - Lambda accesses AWS services via AWS internal network
  # Benefits: 10-100x faster cold start, no ENI issues, $50/month savings

  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-websocket-handler"
    }
  )
}

# ========================================
# CLOUDWATCH LOG GROUPS FOR LAMBDAS
# ========================================
resource "aws_cloudwatch_log_group" "telemetry_processor" {
  name              = "/aws/lambda/${aws_lambda_function.telemetry_processor.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "emergency_orchestrator" {
  name              = "/aws/lambda/${aws_lambda_function.emergency_orchestrator.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "anomaly_detector" {
  name              = "/aws/lambda/${aws_lambda_function.anomaly_detector.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "websocket_handler" {
  name              = "/aws/lambda/${aws_lambda_function.websocket_handler.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = var.tags
}

# ========================================
# ECS CLUSTER
# ========================================
resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-ecs-cluster"
    }
  )
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# ========================================
# APPLICATION LOAD BALANCER
# ========================================
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb-v2"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.environment == "prod"
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  # access_logs {
  #   bucket  = var.s3_logs_bucket
  #   prefix  = "alb"
  #   enabled = true
  # }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-alb-v2"
    }
  )
}

# ALB Listener (HTTP - redirect to HTTPS in production)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "CCS API - Use HTTPS"
      status_code  = "200"
    }
  }
}

# ========================================
# ECS SERVICE - MONITORING SERVICE
# ========================================

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "monitoring_service" {
  name              = "/ecs/${local.name_prefix}/monitoring-service"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = var.tags
}

# Task Definition
resource "aws_ecs_task_definition" "monitoring_service" {
  family                   = "${local.name_prefix}-monitoring-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "monitoring-service"
      image     = "${var.ecr_repository_url}/monitoring-service:latest"
      essential = true
      
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]
      
      environment = [
        { name = "PORT", value = "3000" },
        { name = "ENVIRONMENT", value = var.environment },
        { name = "DYNAMODB_TELEMETRY_TABLE", value = var.dynamodb_telemetry_table_name },
        { name = "REDIS_HOST", value = var.elasticache_endpoint }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.monitoring_service.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-monitoring-service-task"
    }
  )
}

# Target Group
resource "aws_lb_target_group" "monitoring_service" {
  name        = "${local.name_prefix}-monitoring-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-monitoring-tg"
    }
  )
}

# ALB Listener Rule
resource "aws_lb_listener_rule" "monitoring_service" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.monitoring_service.arn
  }

  condition {
    path_pattern {
      values = ["/api/vehicles/*"]
    }
  }
}

# ECS Service
resource "aws_ecs_service" "monitoring_service" {
  name            = "${local.name_prefix}-monitoring-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.monitoring_service.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.monitoring_service.arn
    container_name   = "monitoring-service"
    container_port   = 3000
  }

  health_check_grace_period_seconds = 60
  
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  enable_execute_command = true

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-monitoring-service"
    }
  )

  depends_on = [aws_lb_listener.http]
}

# Auto Scaling
resource "aws_appautoscaling_target" "monitoring_service" {
  max_capacity       = var.ecs_max_capacity
  min_capacity       = var.ecs_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.monitoring_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "monitoring_service_cpu" {
  name               = "${local.name_prefix}-monitoring-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.monitoring_service.resource_id
  scalable_dimension = aws_appautoscaling_target.monitoring_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.monitoring_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "monitoring_service_memory" {
  name               = "${local.name_prefix}-monitoring-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.monitoring_service.resource_id
  scalable_dimension = aws_appautoscaling_target.monitoring_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.monitoring_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ========================================
# DATA SOURCES
# ========================================
data "aws_region" "current" {}

