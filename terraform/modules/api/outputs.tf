output "api_gateway_rest_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_rest_url" {
  description = "API Gateway REST API endpoint URL"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_gateway_rest_arn" {
  description = "API Gateway REST API ARN"
  value       = aws_api_gateway_rest_api.main.arn
}

output "api_gateway_websocket_id" {
  description = "API Gateway WebSocket API ID"
  value       = aws_apigatewayv2_api.websocket.id
}

output "api_gateway_websocket_url" {
  description = "API Gateway WebSocket API endpoint URL"
  value       = aws_apigatewayv2_stage.websocket.invoke_url
}

output "api_gateway_websocket_arn" {
  description = "API Gateway WebSocket API ARN"
  value       = aws_apigatewayv2_api.websocket.arn
}

output "appsync_graphql_url" {
  description = "AppSync GraphQL endpoint URL"
  value       = aws_appsync_graphql_api.main.uris["GRAPHQL"]
}

output "appsync_realtime_url" {
  description = "AppSync real-time endpoint URL"
  value       = aws_appsync_graphql_api.main.uris["REALTIME"]
}

output "appsync_api_id" {
  description = "AppSync API ID"
  value       = aws_appsync_graphql_api.main.id
}

output "appsync_api_arn" {
  description = "AppSync API ARN"
  value       = aws_appsync_graphql_api.main.arn
}

# output "vpc_link_id" {
#   description = "VPC Link ID"
#   value       = aws_api_gateway_vpc_link.main.id
# }

