# CCS AWS Infrastructure - Terraform

This Terraform project implements the complete AWS architecture for CCS (Compañía Colombiana de Seguimiento de Vehículos) real-time vehicle monitoring and emergency response system.

## Architecture Overview

The infrastructure is organized into modular components:

- **Edge Layer**: IoT devices and sensors
- **Ingestion Layer**: AWS IoT Core for device management
- **Processing Layer**: Streaming (Kinesis, SQS) and compute (Lambda)
- **Stage Layer**: Real-time caching and synchronization (ElastiCache, AppSync)
- **Application Layer**: Microservices on ECS Fargate
- **Storage Layer**: DynamoDB, Aurora PostgreSQL, S3, Timestream
- **Security Layer**: Cognito, IAM, KMS, WAF, Secrets Manager
- **Monitoring Layer**: CloudWatch, X-Ray, GuardDuty

## Key Features

- **Emergency Response**: <2 second SLA for critical events
- **High Throughput**: 5,000+ messages/second processing capacity
- **Real-Time Updates**: WebSocket and GraphQL subscriptions
- **Scalable Microservices**: Auto-scaling ECS Fargate services
- **Multi-Environment**: Dev, Staging, and Production configurations

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials
- AWS Account with necessary permissions

## Directory Structure

```
terraform/
├── README.md
├── main.tf                    # Root module
├── variables.tf               # Global variables
├── outputs.tf                 # Global outputs
├── provider.tf                # AWS provider configuration
├── backend.tf                 # Terraform state backend
├── modules/
│   ├── networking/            # VPC, subnets, security groups
│   ├── iot/                   # IoT Core, Thing Registry, Rules
│   ├── streaming/             # Kinesis, SQS, Firehose
│   ├── compute/               # Lambda, ECS Fargate
│   ├── storage/               # DynamoDB, RDS, S3, ElastiCache, Timestream
│   ├── api/                   # API Gateway, AppSync
│   ├── security/              # Cognito, IAM, KMS, WAF
│   ├── monitoring/            # CloudWatch, X-Ray, GuardDuty
│   └── workflows/             # Step Functions
└── environments/
    ├── dev/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── terraform.tfvars
    ├── staging/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── terraform.tfvars
    └── prod/
        ├── main.tf
        ├── variables.tf
        └── terraform.tfvars
```

## Usage

### Initialize Terraform

```bash
cd environments/dev
terraform init
```

### Plan Infrastructure

```bash
terraform plan -out=tfplan
```

### Apply Infrastructure

```bash
terraform apply tfplan
```

### Destroy Infrastructure

```bash
terraform destroy
```

## Module Documentation

Each module contains its own README with detailed documentation:

- [Networking Module](./modules/networking/README.md)
- [IoT Module](./modules/iot/README.md)
- [Streaming Module](./modules/streaming/README.md)
- [Compute Module](./modules/compute/README.md)
- [Storage Module](./modules/storage/README.md)
- [API Module](./modules/api/README.md)
- [Security Module](./modules/security/README.md)
- [Monitoring Module](./modules/monitoring/README.md)
- [Workflows Module](./modules/workflows/README.md)

## Cost Estimation

Estimated monthly costs by environment:

- **Dev**: ~$500-800/month
- **Staging**: ~$1,200-1,500/month
- **Production**: ~$3,500-5,000/month (with reserved instances)

Costs vary based on:
- Number of active vehicles
- Message throughput
- Storage requirements
- Video upload volume

## Security Considerations

- All data encrypted at rest (KMS)
- TLS 1.2+ for data in transit
- X.509 certificates for IoT devices
- WAF rules for API protection
- Multi-AZ for high availability
- Secrets Manager for credential management

## Performance Metrics

- **Emergency Response Latency**: <2 seconds (p99)
- **Telemetry Processing**: 5,000 messages/second
- **API Availability**: 99.99%
- **Database Read Latency**: <10ms (p95)

## Maintenance

### Updating Modules

```bash
terraform get -update
```

### State Management

State is stored in S3 with DynamoDB locking:
- **Dev**: `ccs-terraform-state-dev`
- **Staging**: `ccs-terraform-state-staging`
- **Production**: `ccs-terraform-state-prod`

## Support

For questions or issues, contact the infrastructure team.

