output "kinesis_stream_arn" {
  description = "Kinesis Data Stream ARN"
  value       = aws_kinesis_stream.telemetry.arn
}

output "kinesis_stream_name" {
  description = "Kinesis Data Stream name"
  value       = aws_kinesis_stream.telemetry.name
}

output "emergency_queue_arn" {
  description = "Emergency SQS Queue ARN"
  value       = aws_sqs_queue.emergency.arn
}

output "emergency_queue_url" {
  description = "Emergency SQS Queue URL"
  value       = aws_sqs_queue.emergency.url
}

output "emergency_dlq_arn" {
  description = "Emergency Dead Letter Queue ARN"
  value       = aws_sqs_queue.emergency_dlq.arn
}

output "telemetry_queue_arn" {
  description = "Telemetry SQS Queue ARN"
  value       = aws_sqs_queue.telemetry.arn
}

output "telemetry_queue_url" {
  description = "Telemetry SQS Queue URL"
  value       = aws_sqs_queue.telemetry.url
}

output "telemetry_dlq_arn" {
  description = "Telemetry Dead Letter Queue ARN"
  value       = aws_sqs_queue.telemetry_dlq.arn
}

output "firehose_delivery_stream_arn" {
  description = "Kinesis Firehose delivery stream ARN"
  value       = aws_kinesis_firehose_delivery_stream.data_lake.arn
}

output "firehose_delivery_stream_name" {
  description = "Kinesis Firehose delivery stream name"
  value       = aws_kinesis_firehose_delivery_stream.data_lake.name
}

output "sns_authorities_topic_arn" {
  description = "SNS Authorities alerts topic ARN"
  value       = aws_sns_topic.authorities.arn
}

output "sns_owner_topic_arn" {
  description = "SNS Owner alerts topic ARN"
  value       = aws_sns_topic.owner.arn
}

output "sns_manager_topic_arn" {
  description = "SNS Manager notifications topic ARN"
  value       = aws_sns_topic.manager.arn
}

output "sns_alarm_topic_arn" {
  description = "SNS Alarms topic ARN"
  value       = aws_sns_topic.alarms.arn
}

output "eventbridge_rule_arn" {
  description = "EventBridge high priority rule ARN"
  value       = aws_cloudwatch_event_rule.high_priority_telemetry.arn
}

