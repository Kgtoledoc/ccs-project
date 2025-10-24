output "dashboard_name" {
  description = "CloudWatch Dashboard name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_arn" {
  description = "CloudWatch Dashboard ARN"
  value       = aws_cloudwatch_dashboard.main.dashboard_arn
}

output "log_group_names" {
  description = "CloudWatch Log Group names"
  value       = [aws_cloudwatch_log_group.application_logs.name]
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

output "xray_sampling_rule_arn" {
  description = "X-Ray sampling rule ARN"
  value       = var.enable_xray ? aws_xray_sampling_rule.main[0].arn : null
}

output "alarm_arns" {
  description = "List of CloudWatch Alarm ARNs"
  value = [
    aws_cloudwatch_metric_alarm.emergency_latency_high.arn,
    aws_cloudwatch_metric_alarm.kinesis_iterator_age_high.arn,
    aws_cloudwatch_metric_alarm.dynamodb_user_errors.arn,
    aws_cloudwatch_metric_alarm.alb_unhealthy_hosts.arn,
    aws_cloudwatch_metric_alarm.alb_5xx_errors.arn,
    aws_cloudwatch_metric_alarm.aurora_cpu_high.arn,
    aws_cloudwatch_metric_alarm.elasticache_cpu_high.arn,
    aws_cloudwatch_metric_alarm.elasticache_low_hit_rate.arn,
    aws_cloudwatch_metric_alarm.high_error_rate.arn
  ]
}

