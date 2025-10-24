output "kms_key_id" {
  description = "KMS Key ID"
  value       = var.enable_encryption ? aws_kms_key.main[0].key_id : null
}

output "kms_key_arn" {
  description = "KMS Key ARN"
  value       = var.enable_encryption ? aws_kms_key.main[0].arn : null
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_user_pool_endpoint" {
  description = "Cognito User Pool endpoint"
  value       = aws_cognito_user_pool.main.endpoint
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Web Client ID"
  value       = aws_cognito_user_pool_client.web.id
  sensitive   = true
}

output "cognito_user_pool_mobile_client_id" {
  description = "Cognito User Pool Mobile Client ID"
  value       = aws_cognito_user_pool_client.mobile.id
  sensitive   = true
}

output "cognito_identity_pool_id" {
  description = "Cognito Identity Pool ID"
  value       = aws_cognito_identity_pool.main.id
}

output "cognito_user_pool_domain" {
  description = "Cognito User Pool domain"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "waf_web_acl_id" {
  description = "WAF Web ACL ID"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].id : null
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : null
}

output "db_master_secret_arn" {
  description = "Database master password secret ARN"
  value       = aws_secretsmanager_secret.db_master.arn
}

output "stripe_api_key_secret_arn" {
  description = "Stripe API key secret ARN"
  value       = aws_secretsmanager_secret.stripe_api_key.arn
}

output "gov_api_credentials_secret_arn" {
  description = "Government API credentials secret ARN"
  value       = aws_secretsmanager_secret.gov_api_credentials.arn
}

output "ecs_task_execution_role_arn" {
  description = "ECS Task Execution Role ARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ECS Task Role ARN"
  value       = aws_iam_role.ecs_task.arn
}

output "lambda_execution_role_arn" {
  description = "Lambda Execution Role ARN"
  value       = aws_iam_role.lambda_execution.arn
}

output "iot_core_role_arn" {
  description = "IoT Core Role ARN"
  value       = aws_iam_role.iot_core.arn
}

output "step_functions_role_arn" {
  description = "Step Functions Role ARN"
  value       = aws_iam_role.step_functions.arn
}

output "api_gateway_role_arn" {
  description = "API Gateway Role ARN"
  value       = aws_iam_role.api_gateway.arn
}

output "appsync_role_arn" {
  description = "AppSync Role ARN"
  value       = aws_iam_role.appsync.arn
}

output "firehose_role_arn" {
  description = "Firehose Role ARN"
  value       = aws_iam_role.firehose.arn
}

output "cognito_authenticated_role_arn" {
  description = "Cognito Authenticated Role ARN"
  value       = aws_iam_role.cognito_authenticated.arn
}

