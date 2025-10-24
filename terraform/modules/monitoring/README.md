# Monitoring Module

This module implements comprehensive monitoring and observability for the CCS platform using CloudWatch, X-Ray, and GuardDuty.

## Resources Created

### CloudWatch Dashboard
- Main operational dashboard with 8 widget sections
- Real-time metrics visualization
- Custom namespace metrics

### CloudWatch Alarms (9 total)
1. **Emergency Latency**: <2s SLA monitoring
2. **Kinesis Iterator Age**: Processing lag detection
3. **DynamoDB User Errors**: Database error tracking
4. **ALB Unhealthy Hosts**: Target health monitoring
5. **ALB 5XX Errors**: Application error rates
6. **Aurora CPU**: Database performance
7. **ElastiCache CPU**: Cache performance
8. **ElastiCache Hit Rate**: Cache effectiveness
9. **Application Errors**: Log-based error tracking

### AWS X-Ray
- Distributed tracing enabled
- 5% sampling rate (cost-optimized)
- Service map generation

### AWS GuardDuty
- Threat detection (optional)
- Finding routing to SNS
- S3 data event analysis

### CloudWatch Logs
- Centralized application logs
- Metric filters for error tracking
- KMS encryption

## Dashboard Widgets

### 1. Emergency Response Latency
- **Metric**: Step Functions execution time
- **Target**: <2 seconds (p99)
- **Alert**: Red threshold line at 2s

### 2. Kinesis Telemetry Throughput
- **Metrics**: IncomingRecords, IncomingBytes
- **Period**: 1 minute
- **Display**: Dual y-axis

### 3. DynamoDB Performance
- **Metrics**: Read/Write capacity, UserErrors
- **Table**: Telemetry table
- **Billing**: On-Demand tracking

### 4. ECS Cluster Resources
- **Metrics**: CPU, Memory utilization
- **Cluster**: All tasks aggregated
- **Alert**: >80% sustained

### 5. ALB Health
- **Metrics**: Healthy/Unhealthy hosts, HTTP codes
- **Target**: 100% healthy
- **Error tracking**: 2XX vs 5XX

### 6. Aurora Performance
- **Metrics**: Connections, CPU, Read/Write latency
- **Type**: Cluster-level
- **Target**: <5ms latency

### 7. ElastiCache Performance
- **Metrics**: Hit rate, CPU, Network, Evictions
- **Target**: >90% hit rate
- **Type**: Node-level

### 8. API Gateway
- **Metrics**: Request count, errors, latency
- **Error breakdown**: 4XX vs 5XX
- **Latency**: Average response time

## Alarm Configuration

### Critical Alarms (SNS + PagerDuty)
```
Emergency Latency > 2s        → Immediate escalation
ALB Unhealthy Hosts > 0       → On-call notification
ALB 5XX Errors > 50 (5min)    → On-call notification
```

### High Priority Alarms (SNS)
```
Kinesis Iterator Age > 60s    → DevOps team
Application Errors > 100      → Development team
```

### Medium Priority Alarms (SNS)
```
Aurora CPU > 80%              → Database team
ElastiCache CPU > 75%         → Infrastructure team
DynamoDB User Errors > 10     → Development team
```

### Low Priority Alarms (Email)
```
ElastiCache Hit Rate < 80%    → Performance optimization
```

## X-Ray Tracing

### Enabled Services
- ✅ Lambda functions
- ✅ API Gateway
- ✅ ECS services
- ✅ Step Functions
- ✅ DynamoDB

### Service Map
Visualizes:
- Request flow between services
- Latency at each hop
- Error rates per service
- Downstream dependencies

### Trace Analysis
```bash
# Get trace summary
aws xray get-trace-summaries \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --filter-expression 'service("ccs-prod-*")'

# Get specific trace
aws xray batch-get-traces \
  --trace-ids <trace-id>
```

## GuardDuty Integration

### Finding Types Monitored
- **UnauthorizedAccess**: Unusual API calls
- **Recon**: Port scanning, network probes
- **InstanceCredentialExfiltration**: Compromised credentials
- **CryptoCurrency**: Mining activity
- **Backdoor**: Suspicious network traffic

### Automated Response
```
GuardDuty Finding (Severity ≥4)
    ↓
EventBridge Rule
    ↓
SNS Topic
    ├→ Security Team (Email)
    ├→ PagerDuty (SMS)
    └→ Lambda (Auto-remediation)
```

### Example Remediation
```python
# Lambda function for automated response
def lambda_handler(event, context):
    finding = event['detail']
    finding_type = finding['type']
    severity = finding['severity']
    
    if finding_type.startswith('UnauthorizedAccess'):
        # Disable compromised credentials
        disable_access_key(finding['resource']['accessKeyDetails'])
        
    if severity >= 7:
        # Create incident in PagerDuty
        create_pagerduty_incident(finding)
```

## Log Management

### Retention Policies
| Environment | Retention | Reason |
|-------------|-----------|--------|
| **Dev** | 3 days | Cost optimization |
| **Staging** | 7 days | Testing validation |
| **Prod** | 30 days | Compliance, debugging |

### Log Insights Queries

#### Top Errors (Last Hour)
```
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by @message
| sort count desc
| limit 10
```

#### API Gateway Latency Analysis
```
fields @timestamp, @message
| filter @type = "REPORT"
| stats avg(@duration), max(@duration), min(@duration)
| sort @timestamp desc
```

#### DynamoDB Throttling Events
```
fields @timestamp, @message
| filter @message like /ProvisionedThroughputExceededException/
| count() by bin(5m)
```

## Cost Optimization

### Monthly Cost Estimate
```
CloudWatch Metrics:
- Standard metrics: Free (AWS services)
- Custom metrics: 10 × $0.30 = $3.00
- Dashboard: 1 × $3.00 = $3.00

CloudWatch Alarms:
- Standard: 10 × $0.10 = $1.00
- Composite: 0 × $0.50 = $0.00

CloudWatch Logs:
- Ingestion: 50 GB × $0.50 = $25.00
- Storage: 100 GB × $0.03 = $3.00
- Insights queries: ~$5.00

X-Ray:
- Traces recorded: 100K × $5.00/1M = $0.50
- Traces retrieved: 10K × $0.50/1M = $0.01

GuardDuty:
- CloudTrail analysis: 5M events × $4.50/1M = $22.50
- VPC Flow Logs: 10 GB × $1.00 = $10.00
- S3 Data Events: 1M events × $0.80/1M = $0.80

Total: ~$73/month (production)
```

### Optimization Tips
1. **Sampling**: Use X-Ray sampling (5% vs 100%)
2. **Log Filtering**: Only log WARN/ERROR in prod
3. **Metric Aggregation**: Use CloudWatch Metrics Insights
4. **GuardDuty**: Disable in dev/staging

## Dashboards

### Main Dashboard URL
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=${local.name_prefix}-main-dashboard
```

### Custom Dashboards
Create additional dashboards for specific teams:

```hcl
resource "aws_cloudwatch_dashboard" "database" {
  dashboard_name = "${local.name_prefix}-database-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      # Aurora widgets
      # DynamoDB widgets
      # ElastiCache widgets
    ]
  })
}
```

## Alerting Workflow

```
1. CloudWatch Alarm triggers
    ↓
2. SNS Topic receives notification
    ↓
3. Multiple subscribers notified:
    ├→ Email (ops-team@ccs.co)
    ├→ SMS (+57 300 123 4567)
    ├→ PagerDuty (critical only)
    ├→ Slack webhook
    └→ Lambda (auto-remediation)
    ↓
4. Incident response initiated
```

## Testing

### Trigger Test Alarm
```bash
# Put metric to trigger alarm
aws cloudwatch put-metric-data \
  --namespace CCS/prod \
  --metric-name ErrorCount \
  --value 150 \
  --timestamp $(date -u +%Y-%m-%dT%H:%M:%S)

# Verify alarm state
aws cloudwatch describe-alarms \
  --alarm-names ccs-prod-high-error-rate \
  --state-value ALARM
```

### Generate X-Ray Traces
```bash
# Invoke Lambda with tracing
aws lambda invoke \
  --function-name ccs-prod-telemetry-processor \
  --payload '{"test": true}' \
  /tmp/response.json
```

## Troubleshooting

### Alarm Not Firing
```bash
# Check metric data
aws cloudwatch get-metric-statistics \
  --namespace AWS/States \
  --metric-name ExecutionTime \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 60 \
  --statistics Average

# Verify alarm configuration
aws cloudwatch describe-alarms \
  --alarm-names ccs-prod-emergency-latency-high
```

### Missing Logs
```bash
# Verify log group exists
aws logs describe-log-groups \
  --log-group-name-prefix /application/ccs

# Check log retention
aws logs describe-log-groups \
  --log-group-name /application/ccs-prod \
  --query 'logGroups[0].retentionInDays'
```

### X-Ray Traces Not Appearing
1. Verify IAM permissions for X-Ray
2. Check sampling rule is active
3. Confirm X-Ray daemon is running (ECS)
4. Validate SDK instrumentation

## Usage

```hcl
module "monitoring" {
  source = "./modules/monitoring"

  project_name                   = "ccs"
  environment                    = "prod"
  vpc_id                         = module.networking.vpc_id
  ecs_cluster_name               = module.compute.ecs_cluster_name
  kinesis_stream_name            = module.streaming.kinesis_stream_name
  dynamodb_telemetry_table_name  = module.storage.dynamodb_telemetry_table_name
  aurora_cluster_id              = module.storage.aurora_cluster_id
  elasticache_cluster_id         = module.storage.elasticache_cluster_id
  load_balancer_name             = module.compute.load_balancer_name
  load_balancer_arn_suffix       = module.compute.load_balancer_arn_suffix
  sns_alarm_topic_arn            = module.streaming.sns_alarm_topic_arn
  emergency_workflow_arn         = module.workflows.emergency_workflow_arn
  enable_xray                    = true
  enable_guardduty               = true
  kms_key_id                     = module.security.kms_key_id

  tags = {
    Project = "CCS"
  }
}
```

## References

- [CloudWatch User Guide](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/)
- [X-Ray Developer Guide](https://docs.aws.amazon.com/xray/latest/devguide/)
- [GuardDuty User Guide](https://docs.aws.amazon.com/guardduty/latest/ug/)

