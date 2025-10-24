# Compute Module

This module implements Lambda functions and ECS Fargate services for the CCS platform.

## Resources Created

### Lambda Functions (4)
1. **Telemetry Processor**: Processes vehicle telemetry from Kinesis
2. **Emergency Orchestrator**: Handles emergency events from SQS
3. **Anomaly Detector**: Detects anomalies in telemetry data
4. **WebSocket Handler**: Manages WebSocket connections

### ECS Fargate
- **ECS Cluster**: Container orchestration
- **Monitoring Service**: REST API for vehicle monitoring
- **Application Load Balancer**: HTTP/HTTPS traffic distribution
- **Auto-scaling**: CPU and Memory based scaling

### CloudWatch Logs
- Lambda function logs
- ECS container logs
- ALB access logs

## Lambda Functions

### 1. Telemetry Processor
- **Trigger**: Kinesis Data Stream
- **Batch Size**: 100 records
- **Timeout**: 60s
- **Memory**: 512 MB
- **Concurrency**: 100 reserved

**Functionality**:
- Reads telemetry from Kinesis
- Stores current state in DynamoDB
- Stores metrics in Timestream
- Processes 5,000 msg/second

### 2. Emergency Orchestrator
- **Trigger**: SQS FIFO Queue
- **Batch Size**: 1 (immediate processing)
- **Timeout**: 30s
- **SLA**: <2 seconds

**Functionality**:
- Receives emergency events
- Starts Step Functions workflow
- Ensures <2s response time

### 3. Anomaly Detector
- **Trigger**: IoT Rules or Manual invocation
- **Timeout**: 15s

**Functionality**:
- Detects excessive speed (>120 km/h)
- Detects high temperature (>30°C)
- Detects long idle
- Escalates to emergency queue

### 4. WebSocket Handler
- **Trigger**: API Gateway WebSocket
- **Routes**: connect, disconnect, subscribe, ping

**Functionality**:
- Manages WebSocket connections
- Stores connections in DynamoDB
- Handles vehicle subscriptions
- Broadcasts real-time updates

## ECS Services

### Monitoring Service
- **Type**: Fargate
- **Port**: 3000
- **Protocol**: HTTP
- **Health Check**: /health

**Endpoints**:
- `GET /health`: Health check
- `GET /api/vehicles/:id`: Get vehicle status
- `POST /api/vehicles/batch`: Get multiple vehicles

**Auto-scaling**:
- Min: 2 tasks
- Max: 10 tasks
- CPU Target: 70%
- Memory Target: 80%

## Build & Deploy

### Build Lambda Functions
```bash
cd terraform/modules/compute/lambda_src

# Telemetry Processor
cd telemetry_processor
npm install
cd ..

# Emergency Orchestrator
cd emergency_orchestrator
npm install
cd ..

# Anomaly Detector
cd anomaly_detector
npm install
cd ..

# WebSocket Handler
cd websocket_handler
npm install
cd ..
```

### Build Docker Image
```bash
cd docker_src/monitoring_service

# Build
docker build -t monitoring-service:latest .

# Tag for ECR
docker tag monitoring-service:latest \
  123456789012.dkr.ecr.us-east-1.amazonaws.com/ccs/monitoring-service:latest

# Push to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com

docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/ccs/monitoring-service:latest
```

### Deploy with Terraform
```bash
terraform init
terraform plan
terraform apply
```

## Testing

### Test Lambda Functions Locally
```bash
# Install SAM CLI
brew install aws-sam-cli

# Invoke telemetry processor
sam local invoke TelemetryProcessor \
  -e test_events/kinesis_event.json

# Start API locally
sam local start-api
```

### Test ECS Service
```bash
# Get ALB DNS
terraform output load_balancer_dns

# Test health endpoint
curl http://<alb-dns>/health

# Test vehicle endpoint
curl http://<alb-dns>/api/vehicles/VEH-12345
```

### Load Testing
```bash
# Install Artillery
npm install -g artillery

# Run load test
artillery quick --count 100 --num 1000 \
  http://<alb-dns>/api/vehicles/VEH-12345
```

## Monitoring

### CloudWatch Metrics
- Lambda: Invocations, Errors, Duration, Throttles
- ECS: CPUUtilization, MemoryUtilization
- ALB: TargetResponseTime, HealthyHostCount

### CloudWatch Logs Insights Queries

**Lambda Errors**:
```
fields @timestamp, @message
| filter @type = "ERROR"
| sort @timestamp desc
| limit 20
```

**ECS Container Logs**:
```
fields @timestamp, @message
| filter @logStream like /monitoring-service/
| sort @timestamp desc
```

**ALB Access Logs**:
```
fields @timestamp, request_url, status_code
| filter status_code >= 500
| stats count() by status_code
```

## Troubleshooting

### Lambda Timeout
**Problem**: Lambda exceeds 60s timeout  
**Solution**: Increase batch size, optimize DynamoDB queries

### ECS Task Fails to Start
**Problem**: Task definition invalid  
**Solution**: Check ECR image exists, verify IAM roles

### ALB Returns 502
**Problem**: ECS targets unhealthy  
**Solution**: Check health check path, verify security groups

## Cost Optimization

### Lambda
- Use reserved concurrency wisely
- Optimize memory allocation
- Batch processing where possible

### ECS
- Use Fargate Spot (70% savings)
- Right-size CPU/Memory
- Auto-scaling to match demand

### ALB
- Use least connections algorithm
- Enable connection draining
- Monitor unused target groups

## Usage

```hcl
module "compute" {
  source = "./modules/compute"

  project_name                              = "ccs"
  environment                               = "prod"
  vpc_id                                    = module.networking.vpc_id
  private_subnet_ids                        = module.networking.private_subnet_ids
  public_subnet_ids                         = module.networking.public_subnet_ids
  alb_security_group_id                     = module.networking.alb_security_group_id
  ecs_security_group_id                     = module.networking.ecs_security_group_id
  lambda_security_group_id                  = module.networking.lambda_security_group_id
  
  lambda_execution_role_arn                 = module.security.lambda_execution_role_arn
  ecs_task_execution_role_arn               = module.security.ecs_task_execution_role_arn
  ecs_task_role_arn                         = module.security.ecs_task_role_arn
  
  kinesis_stream_arn                        = module.streaming.kinesis_stream_arn
  emergency_queue_arn                       = module.streaming.emergency_queue_arn
  emergency_queue_url                       = module.streaming.emergency_queue_url
  
  dynamodb_telemetry_table_name             = module.storage.dynamodb_telemetry_table_name
  dynamodb_websocket_connections_table_name = module.storage.dynamodb_websocket_connections_table_name
  timestream_database_name                  = module.storage.timestream_database_name
  timestream_table_name                     = module.storage.timestream_table_name
  elasticache_endpoint                      = module.storage.elasticache_endpoint
  s3_logs_bucket                            = module.storage.s3_logs_bucket
  
  emergency_workflow_arn                    = module.workflows.emergency_workflow_arn
  kms_key_id                                = module.security.kms_key_id

  tags = {
    Project = "CCS"
  }
}
```

## References

- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [ALB User Guide](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)

