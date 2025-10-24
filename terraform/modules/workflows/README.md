# Workflows Module

This module implements AWS Step Functions for orchestrating complex business processes in the CCS platform.

## Resources Created

### Step Functions State Machines
1. **Emergency Workflow**: Critical incident response (<2s SLA)
2. **Business Workflow**: Sales and approval processes

### CloudWatch Log Groups
- Emergency workflow logs (ALL level)
- Business workflow logs (ERROR level)

### EventBridge Rules
- Auto-trigger emergency workflow from SQS

## Emergency Workflow

### Flow Diagram
```
Emergency Event
    ↓
Record Incident (DynamoDB)
    ↓
Determine Response Type
    ├─→ High Priority (panic_button, accident, hijack)
    │       ├─→ Notify Authorities (SNS)
    │       ├─→ Notify Owner (SNS)
    │       └─→ Activate Video Recording (Lambda)
    └─→ Standard Response
            └─→ Notify Owner (SNS)
    ↓
Update Incident Status
    ↓
Log Completion
```

### Key Features
- **Parallel Execution**: Notifications sent simultaneously
- **Retry Logic**: Automatic retries with exponential backoff
- **Error Handling**: Failed incidents recorded for review
- **Tracing**: X-Ray enabled for performance monitoring
- **SLA**: <2 seconds end-to-end

### Triggered By
- IoT Rules Engine → SQS FIFO → EventBridge → Step Functions
- Manual API invocation
- Lambda function

### Example Input
```json
{
  "vehicleId": "VEH-12345",
  "type": "panic_button",
  "severity": "critical",
  "location": {
    "lat": 4.6097,
    "lon": -74.0817
  },
  "eventTimestamp": 1698765432000,
  "metadata": {
    "driver_id": "DRV-789"
  }
}
```

### Example Output
```json
{
  "incidentRecord": {
    "incident_id": {
      "S": "INC-VEH-12345-1698765432000"
    },
    "status": {
      "S": "notified"
    }
  },
  "parallelResults": [
    {
      "authoritiesNotification": {
        "MessageId": "abc-123-def"
      }
    },
    {
      "ownerNotification": {
        "MessageId": "xyz-456-uvw"
      }
    }
  ],
  "executionTime": "1.85s"
}
```

## Business Workflow (Sales)

### Flow Diagram
```
New Contract Request
    ↓
Validate Customer Data (Lambda + External API)
    ↓
Valid? ─NO─→ Validation Failed ❌
    │
    YES
    ↓
Vehicles < 50?
    ├─→ YES: Auto-Approve
    │       ↓
    │   Create Contract
    └─→ NO: Require Manager Approval
            ↓
        Send Manager Notification (SNS)
            ↓
        Wait for Approval (Task Token)
            ↓
        Approved? ─NO─→ Approval Rejected ❌
            │
            YES
            ↓
        Create Contract
    ↓
Process Payment (Stripe via Lambda)
    ↓
Payment Success? ─NO─→ Payment Failed ❌
    │
    YES
    ↓
Activate Service (Lambda)
    ↓
Send Welcome Email (SNS)
    ↓
Complete ✅
```

### Key Features
- **Conditional Logic**: Auto-approve <50 vehicles
- **Human-in-the-Loop**: Manager approval with task token
- **Timeout Handling**: 24-hour approval window
- **Payment Integration**: Stripe via Lambda
- **Retry Policies**: Configurable per task
- **External Integrations**: Government APIs for validation

### Triggered By
- REST API endpoint
- Admin dashboard
- Mobile application

### Example Input
```json
{
  "execution_id": "exec-12345",
  "customer_id": "CUST-98765",
  "document_type": "RUT",
  "document_id": "900123456-7",
  "company_info": {
    "name": "Transportes ABC S.A.S.",
    "tax_id": "900123456-7"
  },
  "number_of_vehicles": 75,
  "contract_type": "premium",
  "estimated_value": 15000000,
  "payment_method": "credit_card",
  "vehicles": [
    {"plate": "ABC-123", "model": "Freightliner"},
    {"plate": "DEF-456", "model": "Volvo"}
  ]
}
```

### Example Output (Auto-Approved)
```json
{
  "validationResult": {
    "valid": true,
    "score": 95
  },
  "contractResult": {
    "contract_id": "CONT-2024-001",
    "approval_type": "automatic"
  },
  "paymentResult": {
    "status": "success",
    "transaction_id": "stripe_tx_123"
  },
  "activationResult": {
    "service_status": "active",
    "vehicles_activated": 75
  }
}
```

## IAM Permissions Required

### Step Functions Role
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:GetItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/ccs-*-incidents"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": [
        "arn:aws:sns:*:*:ccs-*-authorities-alerts",
        "arn:aws:sns:*:*:ccs-*-owner-alerts",
        "arn:aws:sns:*:*:ccs-*-manager-notifications"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": "arn:aws:lambda:*:*:function:ccs-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogDelivery",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/aws/stepfunctions/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords"
      ],
      "Resource": "*"
    }
  ]
}
```

## Testing

### Start Emergency Workflow
```bash
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:123456789:stateMachine:ccs-prod-emergency-workflow \
  --input '{
    "vehicleId": "VEH-TEST-001",
    "type": "panic_button",
    "severity": "critical",
    "location": {"lat": 4.6097, "lon": -74.0817},
    "eventTimestamp": 1698765432000
  }'
```

### Start Business Workflow
```bash
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:123456789:stateMachine:ccs-prod-business-workflow \
  --input '{
    "customer_id": "CUST-TEST-001",
    "number_of_vehicles": 25,
    "contract_type": "standard",
    "estimated_value": 5000000
  }'
```

### Check Execution Status
```bash
aws stepfunctions describe-execution \
  --execution-arn <execution-arn>
```

### Get Execution History
```bash
aws stepfunctions get-execution-history \
  --execution-arn <execution-arn> \
  --max-results 100
```

## Monitoring

### CloudWatch Metrics
- `ExecutionsFailed`: Failed workflow executions
- `ExecutionsSucceeded`: Successful workflow executions
- `ExecutionTime`: Duration of executions
- `ExecutionsTimedOut`: Executions that timed out

### CloudWatch Alarms
```hcl
resource "aws_cloudwatch_metric_alarm" "emergency_workflow_failures" {
  alarm_name          = "${local.name_prefix}-emergency-workflow-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Emergency workflow failures exceeded threshold"
  
  dimensions = {
    StateMachineArn = aws_sfn_state_machine.emergency.arn
  }
}
```

### X-Ray Tracing
View detailed execution traces in X-Ray console:
- Service map showing all dependencies
- Trace details for each execution
- Performance bottlenecks
- Error root cause analysis

## Cost Optimization

### Pricing
- **State Transitions**: $0.025 per 1,000 transitions
- **Express Workflows**: $1.00 per 1M requests + $0.06 per GB-hour

### Monthly Cost Estimate
```
Emergency Workflow:
- 10,000 executions/month
- 8 state transitions per execution
- Total: 80,000 transitions × $0.025/1,000 = $2.00/month

Business Workflow:
- 1,000 executions/month
- 12 state transitions per execution (avg)
- Total: 12,000 transitions × $0.025/1,000 = $0.30/month

Total: ~$2.50/month
```

## Best Practices

### Error Handling
- ✅ Use retry with exponential backoff
- ✅ Implement catch blocks for critical tasks
- ✅ Record failures for analysis
- ✅ Set appropriate timeouts

### Performance
- ✅ Use parallel states for independent tasks
- ✅ Keep payload sizes small (<256 KB)
- ✅ Use ResultPath to preserve input
- ✅ Minimize state transitions

### Security
- ✅ Use IAM roles with least privilege
- ✅ Encrypt sensitive data (KMS)
- ✅ Enable CloudWatch Logs
- ✅ Use X-Ray for tracing

### Reliability
- ✅ Implement idempotent Lambda functions
- ✅ Use DLQ for unprocessable events
- ✅ Monitor execution failures
- ✅ Set realistic timeouts

## Troubleshooting

### Workflow Failures
```bash
# Check recent failed executions
aws stepfunctions list-executions \
  --state-machine-arn <state-machine-arn> \
  --status-filter FAILED \
  --max-results 10

# Get failure details
aws stepfunctions describe-execution \
  --execution-arn <failed-execution-arn>
```

### Common Issues

#### Task Token Timeout
**Problem**: Approval workflow times out after 24 hours  
**Solution**: Implement reminder notifications, reduce timeout

#### DynamoDB Throttling
**Problem**: PutItem fails with ProvisionedThroughputExceededException  
**Solution**: Enable On-Demand billing or increase capacity

#### SNS Delivery Failures
**Problem**: Notifications not received  
**Solution**: Check SNS subscriptions, verify email/SMS confirmation

## Usage

```hcl
module "workflows" {
  source = "./modules/workflows"

  project_name                    = "ccs"
  environment                     = "prod"
  step_functions_role_arn         = module.security.step_functions_role_arn
  sns_authorities_topic_arn       = module.streaming.sns_authorities_topic_arn
  sns_owner_topic_arn             = module.streaming.sns_owner_topic_arn
  sns_manager_topic_arn           = module.streaming.sns_manager_topic_arn
  dynamodb_incidents_table_name   = module.storage.dynamodb_incidents_table_name
  emergency_queue_url             = module.streaming.emergency_queue_url
  kms_key_id                      = module.security.kms_key_id

  tags = {
    Project = "CCS"
  }
}
```

## References

- [AWS Step Functions Developer Guide](https://docs.aws.amazon.com/step-functions/latest/dg/)
- [Amazon States Language](https://states-language.net/spec.html)
- [Step Functions Best Practices](https://docs.aws.amazon.com/step-functions/latest/dg/best-practices.html)

