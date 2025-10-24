# API Module - API Gateway REST, WebSocket, AppSync

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ========================================
# API GATEWAY REST API
# ========================================
resource "aws_api_gateway_rest_api" "main" {
  name        = "${local.name_prefix}-rest-api"
  description = "CCS REST API for vehicle monitoring"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-rest-api"
    }
  )
}

# Cognito Authorizer
resource "aws_api_gateway_authorizer" "cognito" {
  name            = "${local.name_prefix}-cognito-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.main.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [var.cognito_user_pool_arn]
  identity_source = "method.request.header.Authorization"
}

# /vehicles resource
resource "aws_api_gateway_resource" "vehicles" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "vehicles"
}

# /vehicles/{vehicleId} resource
resource "aws_api_gateway_resource" "vehicle_id" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.vehicles.id
  path_part   = "{vehicleId}"
}

# GET /vehicles/{vehicleId} method
resource "aws_api_gateway_method" "get_vehicle" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.vehicle_id.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_parameters = {
    "method.request.path.vehicleId" = true
  }
}

# Integration with ALB
resource "aws_api_gateway_integration" "get_vehicle" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.vehicle_id.id
  http_method = aws_api_gateway_method.get_vehicle.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  uri                     = "http://${var.load_balancer_dns}/api/vehicles/{vehicleId}"

  request_parameters = {
    "integration.request.path.vehicleId" = "method.request.path.vehicleId"
  }

  connection_type = "VPC_LINK"
  connection_id   = aws_api_gateway_vpc_link.main.id
}

# VPC Link to ALB
resource "aws_api_gateway_vpc_link" "main" {
  name        = "${local.name_prefix}-vpc-link"
  target_arns = [var.load_balancer_arn]

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-vpc-link"
    }
  )
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.vehicles.id,
      aws_api_gateway_method.get_vehicle.id,
      aws_api_gateway_integration.get_vehicle.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  xray_tracing_enabled = var.enable_xray

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-api-stage"
    }
  )
}

# WAF Association
# Note: Comentado debido a que count depende de atributos que no se conocen hasta apply
# Descomentar después del primer apply si se requiere WAF
# resource "aws_wafv2_web_acl_association" "api_gateway" {
#   count = var.waf_web_acl_arn != "" ? 1 : 0
#
#   resource_arn = aws_api_gateway_stage.main.arn
#   web_acl_arn  = var.waf_web_acl_arn
# }

# ========================================
# API GATEWAY WEBSOCKET API
# ========================================
resource "aws_apigatewayv2_api" "websocket" {
  name                       = "${local.name_prefix}-websocket-api"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-websocket-api"
    }
  )
}

# WebSocket Routes
resource "aws_apigatewayv2_route" "connect" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.connect.id}"

  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.websocket.id
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.disconnect.id}"
}

resource "aws_apigatewayv2_route" "subscribe" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "subscribe"
  target    = "integrations/${aws_apigatewayv2_integration.subscribe.id}"
}

resource "aws_apigatewayv2_route" "ping" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "ping"
  target    = "integrations/${aws_apigatewayv2_integration.ping.id}"
}

# WebSocket Integrations
resource "aws_apigatewayv2_integration" "connect" {
  api_id             = aws_apigatewayv2_api.websocket.id
  integration_type   = "AWS_PROXY"
  integration_uri    = var.websocket_handler_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "disconnect" {
  api_id             = aws_apigatewayv2_api.websocket.id
  integration_type   = "AWS_PROXY"
  integration_uri    = var.websocket_handler_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "subscribe" {
  api_id             = aws_apigatewayv2_api.websocket.id
  integration_type   = "AWS_PROXY"
  integration_uri    = var.websocket_handler_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "ping" {
  api_id             = aws_apigatewayv2_api.websocket.id
  integration_type   = "AWS_PROXY"
  integration_uri    = var.websocket_handler_arn
  integration_method = "POST"
}

# WebSocket Authorizer
resource "aws_apigatewayv2_authorizer" "websocket" {
  api_id           = aws_apigatewayv2_api.websocket.id
  authorizer_type  = "REQUEST"
  authorizer_uri   = var.websocket_handler_arn
  identity_sources = ["route.request.querystring.token"]
  name             = "${local.name_prefix}-websocket-authorizer"
}

# Lambda Permissions for WebSocket
resource "aws_lambda_permission" "websocket" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.websocket_handler_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket.execution_arn}/*"
}

# WebSocket Stage
resource "aws_apigatewayv2_stage" "websocket" {
  api_id      = aws_apigatewayv2_api.websocket.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.websocket.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  default_route_settings {
    throttling_burst_limit = 5000
    throttling_rate_limit  = 1000
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-websocket-stage"
    }
  )
}

# ========================================
# AWS APPSYNC (GraphQL)
# ========================================
resource "aws_appsync_graphql_api" "main" {
  name                = "${local.name_prefix}-graphql-api"
  authentication_type = "AMAZON_COGNITO_USER_POOLS"

  user_pool_config {
    default_action = "ALLOW"
    user_pool_id   = var.cognito_user_pool_id
    aws_region     = data.aws_region.current.name
  }

  log_config {
    cloudwatch_logs_role_arn = var.appsync_role_arn
    field_log_level          = "ERROR"
  }

  xray_enabled = var.enable_xray

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-graphql-api"
    }
  )
}

# NOTE: AppSync Schema must be deployed separately using AWS CLI or Console
# The aws_appsync_schema resource is not available in the AWS provider
# Example CLI command:
# aws appsync update-graphql-api --api-id <api-id> --schema file://schema.graphql
#
# GraphQL Schema Definition (for reference):
# Save this to a schema.graphql file and deploy manually
/*
schema = <<EOF
type Vehicle {
  vehicleId: ID!
  timestamp: AWSTimestamp!
  location: Location
  speed: Float
  direction: Float
  cargoTemperature: Float
  status: String
}

type Location {
  lat: Float!
  lon: Float!
}

type Query {
  getVehicle(vehicleId: ID!): Vehicle
  listVehicles(limit: Int): [Vehicle]
}

type Mutation {
  updateVehicle(vehicleId: ID!, location: LocationInput, speed: Float): Vehicle
}

input LocationInput {
  lat: Float!
  lon: Float!
}

type Subscription {
  onVehicleUpdate(vehicleId: ID!): Vehicle
    @aws_subscribe(mutations: ["updateVehicle"])
}

schema {
  query: Query
  mutation: Mutation
  subscription: Subscription
}
EOF
*/

# DynamoDB Data Source
resource "aws_appsync_datasource" "dynamodb" {
  api_id           = aws_appsync_graphql_api.main.id
  name             = "DynamoDBDataSource"
  service_role_arn = var.appsync_role_arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = var.dynamodb_telemetry_table_name
    region     = data.aws_region.current.name
  }
}

# Resolver: Query.getVehicle
resource "aws_appsync_resolver" "get_vehicle" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Query"
  field       = "getVehicle"
  data_source = aws_appsync_datasource.dynamodb.name

  request_template = <<EOF
{
  "version": "2017-02-28",
  "operation": "Query",
  "query": {
    "expression": "vehicle_id = :vehicleId",
    "expressionValues": {
      ":vehicleId": $util.dynamodb.toDynamoDBJson($ctx.args.vehicleId)
    }
  },
  "scanIndexForward": false,
  "limit": 1
}
EOF

  response_template = <<EOF
#if($ctx.result.items.size() > 0)
  $util.toJson($ctx.result.items[0])
#else
  null
#end
EOF
}

# ========================================
# CLOUDWATCH LOG GROUPS
# ========================================
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${local.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "websocket" {
  name              = "/aws/apigateway/${local.name_prefix}-websocket"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "appsync" {
  name              = "/aws/appsync/${local.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = var.tags
}

# ========================================
# DATA SOURCES
# ========================================
data "aws_region" "current" {}

