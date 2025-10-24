# Security Module

This module implements security components for the CCS platform including authentication, authorization, encryption, and web application firewall.

## Resources Created

### Authentication & Authorization
- **Cognito User Pool**: User authentication with MFA support
- **Cognito User Pool Clients**: Web and mobile applications
- **Cognito Identity Pool**: AWS resource access for authenticated users
- **User Groups**: Administrators, Viewers, Purchasers, Approvers, Managers

### Encryption
- **KMS Key**: Customer-managed key for encryption at rest
- **KMS Alias**: Alias for easy key reference

### Web Application Firewall
- **WAF Web ACL**: Protection against common web exploits
  - Rate limiting (2000 requests per 5 minutes)
  - AWS Managed Core Rule Set
  - Known Bad Inputs protection
  - SQL Injection protection

### Secrets Management
- **Database Master Password**: Securely stored Aurora credentials
- **Stripe API Key**: Payment gateway credentials
- **Government API Credentials**: External API integration

### IAM Roles
- ECS Task Execution Role
- ECS Task Role
- Lambda Execution Role
- IoT Core Role
- Step Functions Role
- API Gateway Role
- AppSync Role
- Firehose Role

## Cognito User Groups & Roles

### Administrators (Precedence: 1)
- Full system access
- User management
- Configuration changes

### Viewers (Precedence: 2)
- Read-only access
- View vehicle tracking
- View statistics and reports

### Purchasers (Precedence: 3)
- Purchase and contract management
- Billing and payments
- Vehicle registration

### Approvers (Precedence: 4)
- Approve new products and plans
- Alert configuration approval

### Managers (Precedence: 0 - Highest)
- Approve contracts >50 vehicles
- Strategic decisions
- Financial approvals

## Password Policy

- Minimum length: 12 characters
- Requires: uppercase, lowercase, numbers, symbols
- Temporary password validity: 7 days
- MFA: Optional (TOTP)

## WAF Protection

### Rate Limiting
- 2000 requests per 5 minutes per IP
- Automatic blocking on violation

### Managed Rule Sets
1. **Core Rule Set**: Common web vulnerabilities
2. **Known Bad Inputs**: Malicious patterns
3. **SQL Injection**: Database attack prevention

### Optional Geographic Restrictions
Uncomment the GeoBlockRule to block specific countries.

## Secrets Rotation

All secrets support automatic rotation:
- Database passwords: 30 days (recommended)
- API keys: Manual rotation via AWS console
- Recovery window: 7 days before deletion

## Usage

```hcl
module "security" {
  source = "./modules/security"

  project_name       = "ccs"
  environment        = "prod"
  vpc_id             = module.networking.vpc_id
  enable_waf         = true
  enable_encryption  = true

  tags = {
    Project = "CCS"
  }
}
```

## Outputs

- `cognito_user_pool_id`: For API Gateway authorizers
- `kms_key_id`: For encrypting resources
- `waf_web_acl_arn`: For associating with ALB
- `*_role_arn`: IAM roles for services

## Security Best Practices

1. **Encryption**: All data encrypted at rest with KMS
2. **MFA**: Enabled for sensitive operations
3. **Least Privilege**: IAM roles with minimal permissions
4. **Secret Rotation**: Automated rotation policies
5. **Audit Logging**: CloudTrail integration
6. **WAF Protection**: Multiple layers of defense

## Cost Considerations

- **Cognito**: First 50,000 MAU free
- **KMS**: $1/month per key + $0.03/10,000 requests
- **Secrets Manager**: $0.40/month per secret
- **WAF**: $5/month + $1/million requests
- **WAF Rules**: $1/month per rule

## Compliance

- SOC 2 compliant
- ISO 27001 ready
- GDPR considerations in user data handling
- PCI DSS ready (for payment processing)

