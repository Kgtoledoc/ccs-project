# Frontend Module - CloudFront + S3 Static Hosting

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws.us-east-1]
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  s3_origin_id = "S3-${local.name_prefix}-website"
}

# ========================================
# S3 BUCKET FOR STATIC WEBSITE
# ========================================
resource "aws_s3_bucket" "website" {
  bucket = "${local.name_prefix}-website"

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-website"
      Purpose = "Static website hosting"
    }
  )
}

# Bucket Versioning
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

# Block Public Access (CloudFront will access via OAI)
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Policy for old versions
resource "aws_s3_bucket_lifecycle_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"
    
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ========================================
# CLOUDFRONT ORIGIN ACCESS IDENTITY
# ========================================
resource "aws_cloudfront_origin_access_identity" "website" {
  comment = "OAI for ${local.name_prefix} website"
}

# S3 Bucket Policy to allow CloudFront
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAI"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.website.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}

# ========================================
# CLOUDFRONT DISTRIBUTION
# ========================================
resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${local.name_prefix} website distribution"
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class
  aliases             = var.domain_aliases

  # S3 Origin
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.website.cloudfront_access_identity_path
    }
  }

  # API Gateway Origin (optional for /api/* paths)
  dynamic "origin" {
    for_each = var.api_gateway_domain != "" ? [1] : []
    
    content {
      domain_name = var.api_gateway_domain
      origin_id   = "API-Gateway"

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  # Default Cache Behavior (S3)
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Method", "Access-Control-Request-Headers"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600    # 1 hour
    max_ttl                = 86400   # 24 hours
    compress               = true

    # Lambda@Edge for SPA routing (optional)
    dynamic "lambda_function_association" {
      for_each = var.enable_spa_routing ? [1] : []
      
      content {
        event_type   = "origin-response"
        lambda_arn   = aws_lambda_function.edge_spa_router[0].qualified_arn
        include_body = false
      }
    }
  }

  # Cache Behavior for API requests (if API Gateway origin exists)
  dynamic "ordered_cache_behavior" {
    for_each = var.api_gateway_domain != "" ? [1] : []
    
    content {
      path_pattern     = "/api/*"
      allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods   = ["GET", "HEAD", "OPTIONS"]
      target_origin_id = "API-Gateway"

      forwarded_values {
        query_string = true
        headers      = ["Authorization", "Origin", "Accept", "Content-Type"]

        cookies {
          forward = "all"
        }
      }

      viewer_protocol_policy = "https-only"
      min_ttl                = 0
      default_ttl            = 0  # No caching for API
      max_ttl                = 0
      compress               = true
    }
  }

  # Custom Error Response for SPA (404 -> index.html)
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  }

  # Geo Restrictions
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  # SSL Certificate
  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == "" ? true : false
    acm_certificate_arn            = var.acm_certificate_arn != "" ? var.acm_certificate_arn : null
    ssl_support_method             = var.acm_certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  # Logging
  dynamic "logging_config" {
    for_each = var.enable_logging ? [1] : []
    
    content {
      include_cookies = false
      bucket          = var.logs_bucket_domain_name
      prefix          = "cloudfront/"
    }
  }

  # WAF Association
  web_acl_id = var.waf_web_acl_id

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-cloudfront"
    }
  )
}

# ========================================
# LAMBDA@EDGE FOR SPA ROUTING (Optional)
# ========================================
resource "aws_lambda_function" "edge_spa_router" {
  count = var.enable_spa_routing ? 1 : 0

  provider      = aws.us-east-1  # Lambda@Edge must be in us-east-1
  filename      = data.archive_file.edge_spa_router[0].output_path
  function_name = "${local.name_prefix}-edge-spa-router"
  role          = aws_iam_role.edge_lambda[0].arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 5
  memory_size   = 128
  publish       = true  # Required for Lambda@Edge

  source_code_hash = data.archive_file.edge_spa_router[0].output_base64sha256

  tags = var.tags
}

data "archive_file" "edge_spa_router" {
  count = var.enable_spa_routing ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/.terraform/edge_spa_router.zip"

  source {
    content  = <<-EOT
      exports.handler = async (event) => {
        const response = event.Records[0].cf.response;
        const request = event.Records[0].cf.request;
        
        // If 404 or 403, serve index.html
        if (response.status === '404' || response.status === '403') {
          response.status = '200';
          response.statusDescription = 'OK';
          response.body = '';
          response.headers['content-type'] = [{ key: 'Content-Type', value: 'text/html' }];
        }
        
        return response;
      };
    EOT
    filename = "index.js"
  }
}

# IAM Role for Lambda@Edge
resource "aws_iam_role" "edge_lambda" {
  count = var.enable_spa_routing ? 1 : 0

  name = "${local.name_prefix}-edge-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "edgelambda.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "edge_lambda_basic" {
  count = var.enable_spa_routing ? 1 : 0

  role       = aws_iam_role.edge_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ========================================
# CLOUDWATCH LOG GROUP
# ========================================
resource "aws_cloudwatch_log_group" "cloudfront" {
  count = var.enable_logging ? 1 : 0

  name              = "/aws/cloudfront/${local.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = var.tags
}

# ========================================
# ROUTE 53 RECORDS (Optional)
# ========================================
resource "aws_route53_record" "website" {
  count = var.route53_zone_id != "" && length(var.domain_aliases) > 0 ? length(var.domain_aliases) : 0

  zone_id = var.route53_zone_id
  name    = var.domain_aliases[count.index]
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "website_ipv6" {
  count = var.route53_zone_id != "" && length(var.domain_aliases) > 0 ? length(var.domain_aliases) : 0

  zone_id = var.route53_zone_id
  name    = var.domain_aliases[count.index]
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

# ========================================
# CLOUDFRONT CACHE INVALIDATION (via Lambda)
# ========================================
resource "aws_lambda_function" "cache_invalidation" {
  count = var.enable_auto_invalidation ? 1 : 0

  filename         = data.archive_file.cache_invalidation[0].output_path
  function_name    = "${local.name_prefix}-cache-invalidation"
  role             = aws_iam_role.cache_invalidation[0].arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.cache_invalidation[0].output_base64sha256
  runtime          = "python3.11"
  timeout          = 60

  environment {
    variables = {
      DISTRIBUTION_ID = aws_cloudfront_distribution.website.id
    }
  }

  tags = var.tags
}

data "archive_file" "cache_invalidation" {
  count = var.enable_auto_invalidation ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/.terraform/cache_invalidation.zip"

  source {
    content  = <<-EOT
      import boto3
      import os
      import time

      cloudfront = boto3.client('cloudfront')

      def handler(event, context):
          distribution_id = os.environ['DISTRIBUTION_ID']
          
          # Invalidate all paths
          response = cloudfront.create_invalidation(
              DistributionId=distribution_id,
              InvalidationBatch={
                  'Paths': {
                      'Quantity': 1,
                      'Items': ['/*']
                  },
                  'CallerReference': str(time.time())
              }
          )
          
          print(f"Invalidation created: {response['Invalidation']['Id']}")
          return response
    EOT
    filename = "index.py"
  }
}

# IAM Role for Cache Invalidation Lambda
resource "aws_iam_role" "cache_invalidation" {
  count = var.enable_auto_invalidation ? 1 : 0

  name = "${local.name_prefix}-cache-invalidation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "cache_invalidation" {
  count = var.enable_auto_invalidation ? 1 : 0

  name = "${local.name_prefix}-cache-invalidation-policy"
  role = aws_iam_role.cache_invalidation[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation"
        ]
        Resource = aws_cloudfront_distribution.website.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# S3 Event Notification to trigger invalidation on upload
resource "aws_s3_bucket_notification" "website" {
  count = var.enable_auto_invalidation ? 1 : 0

  bucket = aws_s3_bucket.website.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.cache_invalidation[0].arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

resource "aws_lambda_permission" "allow_s3_invoke" {
  count = var.enable_auto_invalidation ? 1 : 0

  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cache_invalidation[0].function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.website.arn
}

