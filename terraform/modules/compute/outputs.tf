output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ECS Cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_cluster_id" {
  description = "ECS Cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "load_balancer_arn" {
  description = "Application Load Balancer ARN"
  value       = aws_lb.main.arn
}

output "load_balancer_dns" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.main.dns_name
}

output "load_balancer_name" {
  description = "Application Load Balancer name"
  value       = aws_lb.main.name
}

output "load_balancer_arn_suffix" {
  description = "Application Load Balancer ARN suffix"
  value       = aws_lb.main.arn_suffix
}

output "load_balancer_listener_arn" {
  description = "ALB HTTP listener ARN"
  value       = aws_lb_listener.http.arn
}

# Lambda Functions
output "telemetry_processor_arn" {
  description = "Telemetry processor Lambda function ARN"
  value       = aws_lambda_function.telemetry_processor.arn
}

output "telemetry_processor_name" {
  description = "Telemetry processor Lambda function name"
  value       = aws_lambda_function.telemetry_processor.function_name
}

output "emergency_orchestrator_arn" {
  description = "Emergency orchestrator Lambda function ARN"
  value       = aws_lambda_function.emergency_orchestrator.arn
}

output "anomaly_detector_arn" {
  description = "Anomaly detector Lambda function ARN"
  value       = aws_lambda_function.anomaly_detector.arn
}

output "websocket_handler_arn" {
  description = "WebSocket handler Lambda function ARN"
  value       = aws_lambda_function.websocket_handler.arn
}

# ECS Service
output "monitoring_service_name" {
  description = "Monitoring ECS service name"
  value       = aws_ecs_service.monitoring_service.name
}

output "monitoring_target_group_arn" {
  description = "Monitoring service target group ARN"
  value       = aws_lb_target_group.monitoring_service.arn
}

