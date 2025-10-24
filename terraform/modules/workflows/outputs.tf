# output "emergency_workflow_arn" {
#   description = "Emergency Step Function workflow ARN"
#   value       = aws_sfn_state_machine.emergency.arn
# }
# 
# output "emergency_workflow_name" {
#   description = "Emergency Step Function workflow name"
#   value       = aws_sfn_state_machine.emergency.name
# }
# 
# output "business_workflow_arn" {
#   description = "Business Step Function workflow ARN"
#   value       = aws_sfn_state_machine.business.arn
# }
# 
# output "business_workflow_name" {
#   description = "Business Step Function workflow name"
#   value       = aws_sfn_state_machine.business.name
# }
# 
# output "emergency_log_group_name" {
#   description = "Emergency workflow log group name"
#   value       = aws_cloudwatch_log_group.emergency_workflow.name
# }
# 
# output "business_log_group_name" {
#   description = "Business workflow log group name"
#   value       = aws_cloudwatch_log_group.business_workflow.name
# }
# 
# output "emergency_trigger_rule_arn" {
#   description = "EventBridge rule ARN for emergency trigger"
#   value       = aws_cloudwatch_event_rule.emergency_trigger.arn
# }
# 
