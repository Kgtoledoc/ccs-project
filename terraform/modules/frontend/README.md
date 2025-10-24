# Frontend Module

This module implements CloudFront CDN + S3 static website hosting for the CCS web application.

## Resources Created

### S3 Bucket
- **Static Website Hosting**: Hosts React SPA build artifacts
- **Versioning**: Enabled for rollback capability
- **Encryption**: AES256 server-side encryption
- **Lifecycle Policies**: Delete old versions after 30 days
- **Access**: Private (CloudFront only via OAI)

### CloudFront Distribution
- **Global CDN**: 300+ edge locations worldwide
- **HTTPS Only**: TLS 1.2+ enforced
- **Multiple Origins**: S3 (static) + API Gateway (optional)
- **Custom Domains**: Support for custom domain names
- **WAF Integration**: Web Application Firewall
- **Cache Behaviors**: Optimized for SPA + API
- **Geo Restrictions**: Optional country-based restrictions

### Lambda@Edge (Optional)
- **SPA Routing**: Handles client-side routing (404 → index.html)
- **Origin Response**: Modifies CloudFront responses
- **Region**: us-east-1 (required for Lambda@Edge)

### Cache Invalidation (Optional)
- **Automatic**: Triggered on S3 object upload
- **Lambda Function**: Creates CloudFront invalidations
- **Paths**: Invalidates all paths (/*) on deployment

### Route 53 (Optional)
- **A Record**: IPv4 alias to CloudFront
- **AAAA Record**: IPv6 alias to CloudFront
- **Multiple Domains**: Supports multiple aliases

## Architecture

```
┌──────────────┐
│  Web Users   │
└──────┬───────┘
       │ HTTPS
       ▼
┌────────────────────────────────────┐
│     CloudFront Distribution        │
│  • 300+ Edge Locations             │
│  • HTTPS/TLS 1.2+                  │
│  • WAF Protection                  │
│  • Lambda@Edge (SPA routing)       │
└────────┬───────────────────────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌─────────┐ ┌──────────────┐
│   S3    │ │ API Gateway  │
│ Website │ │  (optional)  │
│ (React) │ │  /api/*      │
└─────────┘ └──────────────┘
```

## Cache Strategy

### Static Assets (S3 Origin)
- **Default TTL**: 1 hour (3600s)
- **Max TTL**: 24 hours (86400s)
- **Compression**: Enabled (gzip/brotli)
- **Methods**: GET, HEAD, OPTIONS
- **Query Strings**: Ignored
- **Cookies**: Not forwarded

### API Requests (/api/*)
- **TTL**: 0 (no caching)
- **Methods**: All HTTP methods
- **Query Strings**: Forwarded
- **Headers**: Authorization, Origin, Accept, Content-Type
- **Cookies**: All forwarded

## SPA Routing

The module includes Lambda@Edge function to handle Single Page Application routing:

```javascript
// 404 or 403 → serve index.html (200 OK)
if (response.status === '404' || response.status === '403') {
  response.status = '200';
  response.statusDescription = 'OK';
  // Serve index.html from S3
}
```

**Benefit**: React Router (or similar) can handle all routes client-side.

## Deployment Workflow

### 1. Build React App
```bash
cd frontend
npm install
npm run build
# Output: build/ directory
```

### 2. Upload to S3
```bash
aws s3 sync build/ s3://ccs-prod-website/ --delete
```

### 3. Invalidate CloudFront (if auto-invalidation disabled)
```bash
aws cloudfront create-invalidation \
  --distribution-id E1234ABCD5678 \
  --paths "/*"
```

## Custom Domain Setup

### 1. Create ACM Certificate (us-east-1)
```bash
aws acm request-certificate \
  --region us-east-1 \
  --domain-name app.ccs.com \
  --validation-method DNS
```

### 2. Validate Certificate
Add CNAME records provided by ACM to your DNS.

### 3. Configure Module
```hcl
module "frontend" {
  source = "./modules/frontend"
  
  domain_aliases      = ["app.ccs.com"]
  acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxx"
  route53_zone_id     = "Z1234567890ABC"
}
```

## Performance

### CloudFront Metrics
- **Global Latency**: <50ms (p95)
- **Cache Hit Ratio**: >90% (typical for static sites)
- **Availability**: 99.99% SLA
- **Throughput**: Up to 150 Gbps per edge location

### Cost Optimization
```
Data Transfer Out (first 10 TB/month):
  • US/Europe: $0.085/GB
  • Asia: $0.140/GB
  • HTTP/HTTPS Requests: $0.0075 per 10,000

Example (1M users, 10 GB/month):
  • Data Transfer: 10 TB × $0.085 = $850/month
  • Requests: 100M × $0.0075/10K = $75/month
  • Total: ~$925/month
```

## Security

### Features
- ✅ **HTTPS Enforced**: redirect-to-https
- ✅ **TLS 1.2+**: Minimum protocol version
- ✅ **WAF Integration**: Rate limiting, OWASP Top 10
- ✅ **OAI**: S3 not publicly accessible
- ✅ **Geo Restrictions**: Block/allow by country
- ✅ **Signed URLs**: (optional) for premium content

### Best Practices
- Certificate in us-east-1 (CloudFront requirement)
- Enable logging for compliance
- Rotate invalidation patterns (avoid /*)
- Use versioned URLs for assets (cache busting)

## Testing

### Test CloudFront Distribution
```bash
# Get distribution URL
CLOUDFRONT_URL=$(terraform output -raw cloudfront_domain_name)

# Test static assets
curl -I https://$CLOUDFRONT_URL/index.html
curl -I https://$CLOUDFRONT_URL/static/css/main.css

# Test SPA routing
curl -I https://$CLOUDFRONT_URL/dashboard
# Should return 200 (index.html served)

# Test API routing (if configured)
curl https://$CLOUDFRONT_URL/api/vehicles/VEH-001
```

### Test Cache Headers
```bash
curl -I https://$CLOUDFRONT_URL/index.html | grep -i cache
# Look for:
# x-cache: Hit from cloudfront
# cache-control: max-age=3600
```

### Load Testing
```bash
# Install Apache Bench
sudo apt install apache2-utils

# Test 1000 requests, 10 concurrent
ab -n 1000 -c 10 https://$CLOUDFRONT_URL/
```

## Monitoring

### CloudWatch Metrics
- **Requests**: Total requests per distribution
- **BytesDownloaded**: Total data transfer
- **ErrorRate**: 4xx and 5xx error rates
- **CacheHitRate**: Percentage of cached responses

### CloudWatch Alarms (recommended)
```hcl
resource "aws_cloudwatch_metric_alarm" "cloudfront_error_rate" {
  alarm_name          = "cloudfront-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  
  dimensions = {
    DistributionId = aws_cloudfront_distribution.website.id
  }
}
```

## Troubleshooting

### 403 Forbidden
**Problem**: CloudFront returns 403 when accessing files  
**Solution**: Check S3 bucket policy allows OAI

### Stale Content
**Problem**: Old content served after deployment  
**Solution**: Create CloudFront invalidation or enable auto-invalidation

### Custom Domain Not Working
**Problem**: Domain shows SSL certificate error  
**Solution**: Ensure ACM certificate is in us-east-1 and validated

### SPA Routes Return 404
**Problem**: Direct navigation to routes fails  
**Solution**: Enable `enable_spa_routing = true`

## Cost Optimization

### Tips
1. **Use Cache Effectively**: Increase TTL for static assets
2. **Compress Assets**: gzip/brotli reduces transfer costs
3. **Price Class**: Use PriceClass_100 (US/EU only) if appropriate
4. **Invalidations**: Minimize frequency (cost: $0.005 per path)
5. **Versioned URLs**: Avoid invalidations entirely

### Example Savings
```
Without Optimization:
  • Data Transfer: 50 TB/month × $0.085 = $4,250
  • Invalidations: 100/day × 30 × $0.005 = $15
  • Total: $4,265/month

With Optimization:
  • Data Transfer: 30 TB (40% compression) × $0.085 = $2,550
  • Invalidations: 0 (versioned URLs) = $0
  • Total: $2,550/month
  
Savings: $1,715/month (40%)
```

## Usage

```hcl
module "frontend" {
  source = "./modules/frontend"

  project_name = "ccs"
  environment  = "prod"

  # CloudFront Configuration
  cloudfront_price_class = "PriceClass_100"
  domain_aliases         = ["app.ccs.com", "www.app.ccs.com"]
  acm_certificate_arn    = "arn:aws:acm:us-east-1:123456789012:certificate/xxx"

  # API Integration
  api_gateway_domain = module.api.api_gateway_rest_url

  # Features
  enable_spa_routing        = true
  enable_auto_invalidation  = true
  enable_logging            = true

  # Security
  waf_web_acl_id = module.security.waf_web_acl_id

  # Logging
  logs_bucket_domain_name = module.storage.s3_logs_bucket_domain_name
  log_retention_days      = 30
  kms_key_id              = module.security.kms_key_id

  # DNS
  route53_zone_id = "Z1234567890ABC"

  # Geo Restrictions (optional)
  geo_restriction_type      = "whitelist"
  geo_restriction_locations = ["US", "CA", "MX", "CO"]

  tags = {
    Project = "CCS"
  }
}
```

## Outputs

```hcl
output "website_url" {
  value = module.frontend.website_url
}

output "cloudfront_distribution_id" {
  value = module.frontend.cloudfront_distribution_id
}

output "s3_bucket_name" {
  value = module.frontend.s3_bucket_name
}
```

## References

- [CloudFront Developer Guide](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/)
- [Lambda@Edge Guide](https://docs.aws.amazon.com/lambda/latest/dg/lambda-edge.html)
- [S3 Static Website Hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [CloudFront Pricing](https://aws.amazon.com/cloudfront/pricing/)

