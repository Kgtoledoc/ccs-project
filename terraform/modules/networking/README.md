# Networking Module

This module creates the VPC infrastructure for the CCS platform including subnets, NAT gateways, security groups, and VPC endpoints.

## Resources Created

- VPC with DNS support
- 3 Public subnets (one per AZ)
- 3 Private subnets (one per AZ)
- 3 Database subnets (one per AZ)
- Internet Gateway
- NAT Gateways (one per AZ for high availability)
- Route tables and associations
- Security groups for ALB, ECS, Lambda, Database, and Cache
- VPC Endpoints (S3, DynamoDB, ECR, CloudWatch Logs, Secrets Manager)

## Architecture

```
Internet
    ↓
Internet Gateway
    ↓
Public Subnets (10.0.0.x/24, 10.0.1.x/24, 10.0.2.x/24)
    ↓
NAT Gateways
    ↓
Private Subnets (10.0.10.x/24, 10.0.11.x/24, 10.0.12.x/24)
    ↓
Database Subnets (10.0.20.x/24, 10.0.21.x/24, 10.0.22.x/24)
```

## Security Groups

### ALB Security Group
- Ingress: Port 80 (HTTP), 443 (HTTPS) from Internet
- Egress: All traffic

### ECS Security Group
- Ingress: All ports from ALB, VPC CIDR
- Egress: All traffic

### Lambda Security Group
- Egress: All traffic

### Database Security Group
- Ingress: Port 5432 (PostgreSQL) from ECS and Lambda
- Egress: All traffic

### Cache Security Group
- Ingress: Port 6379 (Redis) from ECS and Lambda
- Egress: All traffic

### VPC Endpoints Security Group
- Ingress: Port 443 from VPC CIDR
- Egress: All traffic

## VPC Endpoints

Gateway Endpoints (no additional cost):
- S3
- DynamoDB

Interface Endpoints (hourly cost):
- ECR API
- ECR DKR
- CloudWatch Logs
- Secrets Manager

## Usage

```hcl
module "networking" {
  source = "./modules/networking"

  project_name       = "ccs"
  environment        = "prod"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  tags = {
    Project = "CCS"
  }
}
```

## Outputs

- `vpc_id`: VPC ID
- `public_subnet_ids`: List of public subnet IDs
- `private_subnet_ids`: List of private subnet IDs
- `database_subnet_ids`: List of database subnet IDs
- `alb_security_group_id`: ALB security group ID
- `ecs_security_group_id`: ECS security group ID
- `database_security_group_id`: Database security group ID
- And more...

## Cost Considerations

- **NAT Gateways**: ~$0.045/hour per NAT Gateway × 3 AZs = ~$97/month
- **VPC Endpoints (Interface)**: ~$0.01/hour per endpoint × 4 = ~$29/month
- **Data Transfer**: NAT Gateway data processing charges apply

## High Availability

- Multi-AZ deployment across 3 availability zones
- One NAT Gateway per AZ for redundancy
- Database and cache subnets isolated in separate subnet tier

