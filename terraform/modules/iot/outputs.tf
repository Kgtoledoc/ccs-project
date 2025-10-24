output "iot_endpoint" {
  description = "AWS IoT Core endpoint"
  value       = data.aws_iot_endpoint.main.endpoint_address
}

output "thing_type_arn" {
  description = "IoT Thing Type ARN"
  value       = aws_iot_thing_type.vehicle.arn
}

output "thing_type_name" {
  description = "IoT Thing Type name"
  value       = aws_iot_thing_type.vehicle.name
}

output "vehicle_policy_name" {
  description = "IoT Policy name for vehicles"
  value       = aws_iot_policy.vehicle.name
}

output "vehicle_policy_arn" {
  description = "IoT Policy ARN for vehicles"
  value       = aws_iot_policy.vehicle.arn
}

# NOTE: Commented out because emergency rule is commented
# output "emergency_rule_arn" {
#   description = "Emergency IoT Rule ARN"
#   value       = aws_iot_topic_rule.emergency.arn
# }

output "telemetry_rule_arn" {
  description = "Telemetry IoT Rule ARN"
  value       = aws_iot_topic_rule.telemetry.arn
}

output "test_vehicle_certificate_arn" {
  description = "Test vehicle certificate ARN (dev only)"
  value       = var.environment == "dev" ? aws_iot_certificate.test_vehicle[0].arn : null
}

output "test_vehicle_certificate_pem" {
  description = "Test vehicle certificate PEM (dev only)"
  value       = var.environment == "dev" ? aws_iot_certificate.test_vehicle[0].certificate_pem : null
  sensitive   = true
}

output "test_vehicle_private_key" {
  description = "Test vehicle private key (dev only)"
  value       = var.environment == "dev" ? aws_iot_certificate.test_vehicle[0].private_key : null
  sensitive   = true
}

output "test_vehicle_thing_name" {
  description = "Test vehicle thing name (dev only)"
  value       = var.environment == "dev" ? aws_iot_thing.test_vehicle[0].name : null
}

output "iot_log_group_name" {
  description = "IoT error log group name"
  value       = aws_cloudwatch_log_group.iot_errors.name
}

