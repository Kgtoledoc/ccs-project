# Security Module - Cognito, IAM, KMS, WAF, Secrets Manager

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ========================================
# KMS KEY FOR ENCRYPTION
# ========================================
resource "aws_kms_key" "main" {
  count = var.enable_encryption ? 1 : 0

  description             = "KMS key for ${local.name_prefix} encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-kms-key"
    }
  )
}

resource "aws_kms_alias" "main" {
  count = var.enable_encryption ? 1 : 0

  name          = "alias/${local.name_prefix}"
  target_key_id = aws_kms_key.main[0].key_id
}

# ========================================
# COGNITO USER POOL
# ========================================
resource "aws_cognito_user_pool" "main" {
  name = "${local.name_prefix}-user-pool"

  # Password Policy
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # MFA Configuration
  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  # Account Recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
    recovery_mechanism {
      name     = "verified_phone_number"
      priority = 2
    }
  }

  # User Attributes
  schema {
    name                = "email"
    attribute_data_type = "String"
    mutable             = true
    required            = true

    string_attribute_constraints {
      min_length = 5
      max_length = 255
    }
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    mutable             = true
    required            = true

    string_attribute_constraints {
      min_length = 1
      max_length = 255
    }
  }

  # Custom Attributes
  schema {
    name                = "company_id"
    attribute_data_type = "String"
    mutable             = true
    required            = false

    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  schema {
    name                = "role"
    attribute_data_type = "String"
    mutable             = true
    required            = false

    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  # Email Configuration
  auto_verified_attributes = ["email"]

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # User Pool Add-ons
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  # Lambda Triggers (optional - can be configured later)
  # lambda_config {
  #   pre_sign_up = aws_lambda_function.cognito_pre_signup.arn
  # }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-user-pool"
    }
  )
}

# ========================================
# COGNITO USER POOL DOMAIN
# ========================================
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${local.name_prefix}-auth"
  user_pool_id = aws_cognito_user_pool.main.id
}

# ========================================
# COGNITO USER POOL CLIENT - WEB
# ========================================
resource "aws_cognito_user_pool_client" "web" {
  name         = "${local.name_prefix}-web-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret                      = false
  refresh_token_validity               = 30
  access_token_validity                = 1
  id_token_validity                    = 1
  token_validity_units {
    refresh_token = "days"
    access_token  = "hours"
    id_token      = "hours"
  }

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]

  prevent_user_existence_errors = "ENABLED"

  read_attributes = [
    "email",
    "email_verified",
    "name",
    "custom:company_id",
    "custom:role"
  ]

  write_attributes = [
    "email",
    "name",
    "custom:company_id",
    "custom:role"
  ]
}

# ========================================
# COGNITO USER POOL CLIENT - MOBILE
# ========================================
resource "aws_cognito_user_pool_client" "mobile" {
  name         = "${local.name_prefix}-mobile-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret                      = false
  refresh_token_validity               = 30
  access_token_validity                = 1
  id_token_validity                    = 1
  token_validity_units {
    refresh_token = "days"
    access_token  = "hours"
    id_token      = "hours"
  }

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  prevent_user_existence_errors = "ENABLED"

  read_attributes = [
    "email",
    "email_verified",
    "name",
    "custom:company_id",
    "custom:role"
  ]

  write_attributes = [
    "email",
    "name"
  ]
}

# ========================================
# COGNITO USER GROUPS
# ========================================
resource "aws_cognito_user_group" "admin" {
  name         = "Administrators"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Full system access"
  precedence   = 1
}

resource "aws_cognito_user_group" "viewer" {
  name         = "Viewers"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Read-only access"
  precedence   = 2
}

resource "aws_cognito_user_group" "purchaser" {
  name         = "Purchasers"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Purchase and contract management"
  precedence   = 3
}

resource "aws_cognito_user_group" "approver" {
  name         = "Approvers"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Approval of new products and plans"
  precedence   = 4
}

resource "aws_cognito_user_group" "manager" {
  name         = "Managers"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Manager approval for large contracts"
  precedence   = 0
}

# ========================================
# COGNITO IDENTITY POOL
# ========================================
resource "aws_cognito_identity_pool" "main" {
  identity_pool_name               = "${local.name_prefix}-identity-pool"
  allow_unauthenticated_identities = false
  allow_classic_flow               = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.web.id
    provider_name           = aws_cognito_user_pool.main.endpoint
    server_side_token_check = true
  }

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.mobile.id
    provider_name           = aws_cognito_user_pool.main.endpoint
    server_side_token_check = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-identity-pool"
    }
  )
}

# ========================================
# IAM ROLES FOR COGNITO IDENTITY POOL
# ========================================

# Authenticated Role
resource "aws_iam_role" "cognito_authenticated" {
  name = "${local.name_prefix}-cognito-authenticated-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.main.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-cognito-authenticated-role"
    }
  )
}

resource "aws_iam_role_policy" "cognito_authenticated" {
  name = "${local.name_prefix}-cognito-authenticated-policy"
  role = aws_iam_role.cognito_authenticated.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-identity:*",
          "cognito-sync:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach Identity Pool Roles
resource "aws_cognito_identity_pool_roles_attachment" "main" {
  identity_pool_id = aws_cognito_identity_pool.main.id

  roles = {
    authenticated = aws_iam_role.cognito_authenticated.arn
  }
}

# ========================================
# AWS WAF WEB ACL
# ========================================
resource "aws_wafv2_web_acl" "main" {
  count = var.enable_waf ? 1 : 0

  name  = "${local.name_prefix}-web-acl"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate Limiting Rule
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Core Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - SQL Injection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # Geographic Restriction (Example: Block countries)
  # rule {
  #   name     = "GeoBlockRule"
  #   priority = 5
  #
  #   action {
  #     block {}
  #   }
  #
  #   statement {
  #     geo_match_statement {
  #       country_codes = ["CN", "RU", "KP"]
  #     }
  #   }
  #
  #   visibility_config {
  #     cloudwatch_metrics_enabled = true
  #     metric_name                = "${local.name_prefix}-geo-block"
  #     sampled_requests_enabled   = true
  #   }
  # }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-web-acl"
    sampled_requests_enabled   = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-web-acl"
    }
  )
}

# ========================================
# SECRETS MANAGER
# ========================================

# Database Master Password
resource "random_password" "db_master" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "db_master" {
  name                    = "${local.name_prefix}-db-master-password"
  description             = "Master password for Aurora PostgreSQL"
  recovery_window_in_days = 7
  kms_key_id              = var.enable_encryption ? aws_kms_key.main[0].id : null

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-db-master-password"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db_master" {
  secret_id = aws_secretsmanager_secret.db_master.id
  secret_string = jsonencode({
    username = "ccsadmin"
    password = random_password.db_master.result
    engine   = "postgres"
    port     = 5432
  })
}

# Stripe API Key (placeholder)
resource "aws_secretsmanager_secret" "stripe_api_key" {
  name                    = "${local.name_prefix}-stripe-api-key"
  description             = "Stripe API key for payment processing"
  recovery_window_in_days = 7
  kms_key_id              = var.enable_encryption ? aws_kms_key.main[0].id : null

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-stripe-api-key"
    }
  )
}

resource "aws_secretsmanager_secret_version" "stripe_api_key" {
  secret_id = aws_secretsmanager_secret.stripe_api_key.id
  secret_string = jsonencode({
    api_key    = "sk_test_placeholder"
    public_key = "pk_test_placeholder"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Government Registry API Credentials
resource "aws_secretsmanager_secret" "gov_api_credentials" {
  name                    = "${local.name_prefix}-gov-api-credentials"
  description             = "Government registry API credentials"
  recovery_window_in_days = 7
  kms_key_id              = var.enable_encryption ? aws_kms_key.main[0].id : null

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-gov-api-credentials"
    }
  )
}

resource "aws_secretsmanager_secret_version" "gov_api_credentials" {
  secret_id = aws_secretsmanager_secret.gov_api_credentials.id
  secret_string = jsonencode({
    api_key    = "placeholder"
    api_secret = "placeholder"
    endpoint   = "https://api.government.co"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ========================================
# IAM ROLES FOR SERVICES
# ========================================

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name_prefix}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-ecs-task-execution-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "${local.name_prefix}-ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Resource = [
          aws_secretsmanager_secret.db_master.arn,
          aws_secretsmanager_secret.stripe_api_key.arn,
          aws_secretsmanager_secret.gov_api_credentials.arn
        ]
      }
    ]
  })
}

# ECS Task Role
resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-ecs-task-role"
    }
  )
}

# Lambda Execution Role
resource "aws_iam_role" "lambda_execution" {
  name = "${local.name_prefix}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-lambda-execution-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "lambda_execution_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_execution_vpc" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# IoT Core Role
resource "aws_iam_role" "iot_core" {
  name = "${local.name_prefix}-iot-core-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "iot.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-iot-core-role"
    }
  )
}

# Step Functions Role
resource "aws_iam_role" "step_functions" {
  name = "${local.name_prefix}-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-step-functions-role"
    }
  )
}

# API Gateway Role
resource "aws_iam_role" "api_gateway" {
  name = "${local.name_prefix}-api-gateway-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-api-gateway-role"
    }
  )
}

# AppSync Role
resource "aws_iam_role" "appsync" {
  name = "${local.name_prefix}-appsync-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "appsync.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-appsync-role"
    }
  )
}

# Firehose Role
resource "aws_iam_role" "firehose" {
  name = "${local.name_prefix}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-firehose-role"
    }
  )
}

