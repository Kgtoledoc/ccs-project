# IoT Module

This module implements AWS IoT Core infrastructure for CCS vehicle fleet management.

## Resources Created

### IoT Thing Management
- **Thing Type**: Vehicle device classification
- **IoT Policy**: Granular permissions for devices
- **Fleet Indexing**: Searchable device registry
- **Test Vehicle**: Development testing (dev environment only)

### IoT Rules Engine
1. **Emergency Rule**: Routes panic button/critical events to SQS FIFO (<2s)
2. **Telemetry Rule**: Routes normal telemetry to Kinesis
3. **Video Metadata Rule**: Indexes video metadata in DynamoDB
4. **High Temperature Alert**: SNS notification when cargo temp >30°C
5. **Speeding Alert**: SNS notification when speed >120 km/h
6. **Long Idle Detection**: Lambda for anomaly detection

### Security
- X.509 certificate-based authentication
- Policy-based authorization
- Encrypted connections (TLS 1.2+)
- KMS encryption for logs

## Architecture

```
Vehicle Sensors → MQTT over TLS 1.2 → IoT Core
                                          ↓
                                    Rules Engine
                      ┌──────────────────┴──────────────────┐
                      ↓                  ↓                   ↓
              Emergency Events    Normal Telemetry    Video Metadata
                      ↓                  ↓                   ↓
                  SQS FIFO           Kinesis             DynamoDB
```

## IoT Topics

### Publishing (Device → Cloud)
- `vehicle/{vehicleId}/telemetry`: Normal telemetry data
- `vehicle/{vehicleId}/emergency`: Critical events
- `vehicle/{vehicleId}/video-metadata`: Video upload info

### Subscribing (Cloud → Device)
- `vehicle/{vehicleId}/commands`: Remote commands

### Thing Shadow
- `$aws/things/{vehicleId}/shadow/update`: Update device state
- `$aws/things/{vehicleId}/shadow/get`: Retrieve device state

## Message Formats

### Telemetry Message
```json
{
  "vehicleId": "VEH-12345",
  "timestamp": 1698765432000,
  "location": {
    "lat": 4.6097,
    "lon": -74.0817
  },
  "speed": 65.5,
  "direction": 180,
  "cargo_temperature": 22.5,
  "interior_temperature": 24.0,
  "engine_status": "on",
  "fuel_level": 75.5,
  "odometer": 125430
}
```

### Emergency Message
```json
{
  "vehicleId": "VEH-12345",
  "timestamp": 1698765432000,
  "type": "panic_button",
  "severity": "critical",
  "location": {
    "lat": 4.6097,
    "lon": -74.0817
  },
  "metadata": {
    "driver_id": "DRV-789",
    "route_id": "ROUTE-456"
  }
}
```

## Device Provisioning

### Manual Provisioning (Development)
```bash
# Create thing
aws iot create-thing \
  --thing-name VEH-12345 \
  --thing-type-name ccs-dev-vehicle-thing-type \
  --attribute-payload '{"vehicleId":"VEH-12345","region":"us-east-1"}'

# Create certificate
aws iot create-keys-and-certificate \
  --set-as-active \
  --certificate-pem-outfile vehicle-cert.pem \
  --public-key-outfile vehicle-public.key \
  --private-key-outfile vehicle-private.key

# Attach policy
aws iot attach-policy \
  --policy-name ccs-dev-vehicle-policy \
  --target <certificate-arn>

# Attach certificate to thing
aws iot attach-thing-principal \
  --thing-name VEH-12345 \
  --principal <certificate-arn>
```

### Fleet Provisioning (Production)
Use AWS IoT Fleet Provisioning for automated device onboarding:
```json
{
  "templateName": "CCSVehicleProvisioning",
  "templateBody": {
    "Parameters": {
      "VehicleId": {"Type": "String"},
      "FleetId": {"Type": "String"}
    },
    "Resources": {
      "thing": {
        "Type": "AWS::IoT::Thing",
        "Properties": {
          "ThingName": {"Ref": "VehicleId"},
          "ThingTypeName": "ccs-prod-vehicle-thing-type",
          "AttributePayload": {
            "vehicleId": {"Ref": "VehicleId"},
            "fleetId": {"Ref": "FleetId"}
          }
        }
      },
      "certificate": {
        "Type": "AWS::IoT::Certificate",
        "Properties": {
          "CertificateMode": "DEFAULT",
          "Status": "ACTIVE"
        }
      },
      "policy": {
        "Type": "AWS::IoT::Policy",
        "Properties": {
          "PolicyName": "ccs-prod-vehicle-policy"
        }
      }
    }
  }
}
```

## Testing

### MQTT Test Client
```bash
# Subscribe to all vehicle topics
mosquitto_sub -h <iot-endpoint> \
  --cert vehicle-cert.pem \
  --key vehicle-private.key \
  --cafile AmazonRootCA1.pem \
  -t 'vehicle/+/#' \
  -v

# Publish test telemetry
mosquitto_pub -h <iot-endpoint> \
  --cert vehicle-cert.pem \
  --key vehicle-private.key \
  --cafile AmazonRootCA1.pem \
  -t 'vehicle/VEH-12345/telemetry' \
  -m '{"vehicleId":"VEH-12345","speed":65.5,"location":{"lat":4.6097,"lon":-74.0817}}'

# Publish emergency
mosquitto_pub -h <iot-endpoint> \
  --cert vehicle-cert.pem \
  --key vehicle-private.key \
  --cafile AmazonRootCA1.pem \
  -t 'vehicle/VEH-12345/emergency' \
  -m '{"vehicleId":"VEH-12345","type":"panic_button","severity":"critical"}'
```

### AWS IoT MQTT Test Console
1. Navigate to AWS IoT Console
2. Go to Test → MQTT test client
3. Subscribe to `vehicle/#`
4. Publish test messages

## Performance

### Connection Limits
- **Concurrent Connections**: 500,000 per account
- **Connection Rate**: 500 connections/second
- **Message Rate**: 20,000 messages/second per connection

### Message Limits
- **Max Message Size**: 128 KB
- **QoS Levels**: 0 (at most once), 1 (at least once)
- **Retained Messages**: Supported

### Latency
- **Publish to Rule**: <100ms (p95)
- **Rule to Action**: <200ms (p95)
- **End-to-End**: <500ms (p95)

## Cost Optimization

### Pricing (us-east-1)
- **Connectivity**: $0.08 per million minutes
- **Messaging**: $1.00 per million messages
- **Rules Actions**: $0.15 per million actions
- **Device Shadow**: $1.25 per million updates

### Monthly Cost Estimate (5,000 vehicles)
```
Assumptions:
- 5,000 vehicles
- 24/7 connection
- 1 message every 30 seconds = 2,880 msg/day/vehicle
- Total: 14.4M messages/day = 432M messages/month

Connectivity: 5,000 vehicles × 43,200 min/month × $0.08/1M = $17.28
Messaging: 432M messages × $1.00/1M = $432.00
Rules (3 rules): 432M × 3 × $0.15/1M = $194.40
Device Shadow: 432M updates × $1.25/1M = $540.00

Total: ~$1,184/month
```

### Optimization Tips
1. **Batch Messages**: Combine multiple readings
2. **Message Compression**: Use compressed formats
3. **Smart Sampling**: Reduce frequency when stationary
4. **Shadow Updates**: Only on significant changes

## Security Best Practices

### Certificate Management
- ✅ Use X.509 certificates per device
- ✅ Rotate certificates every 12 months
- ✅ Revoke compromised certificates immediately
- ✅ Store private keys securely on device

### Policy Design
- ✅ Use `${iot:Connection.Thing.ThingName}` for authorization
- ✅ Restrict topics to device-specific paths
- ✅ Deny by default, allow explicitly
- ✅ Regular policy audits

### Network Security
- ✅ TLS 1.2+ only
- ✅ Certificate pinning on devices
- ✅ VPC endpoints for rule destinations
- ✅ CloudWatch Logs for audit trail

## Monitoring

### Key Metrics
- `PublishIn.Success`: Successful incoming messages
- `PublishIn.AuthError`: Authentication failures
- `RuleMessageThrottled`: Rule throttling
- `RuleNotFound`: Messages with no matching rule
- `ParseError`: Malformed messages

### CloudWatch Alarms
```hcl
# High error rate alarm
resource "aws_cloudwatch_metric_alarm" "iot_high_error_rate" {
  alarm_name          = "${local.name_prefix}-iot-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "PublishIn.AuthError"
  namespace           = "AWS/IoT"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "IoT authentication errors exceeded threshold"
  alarm_actions       = [var.sns_alarm_topic_arn]
}
```

## Troubleshooting

### Connection Issues
```bash
# Check connectivity
openssl s_client -connect <iot-endpoint>:8883 \
  -cert vehicle-cert.pem \
  -key vehicle-private.key

# Verify certificate
aws iot describe-certificate --certificate-id <cert-id>

# Check thing attachment
aws iot list-thing-principals --thing-name VEH-12345
```

### Rule Issues
```bash
# Enable CloudWatch Logs
aws iot set-v2-logging-options \
  --default-log-level INFO \
  --role-arn <iot-role-arn>

# Check rule metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/IoT \
  --metric-name RuleMessageThrottled \
  --dimensions Name=RuleName,Value=ccs_prod_emergency_rule \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

## Usage

```hcl
module "iot" {
  source = "./modules/iot"

  project_name                   = "ccs"
  environment                    = "prod"
  kinesis_stream_name            = module.streaming.kinesis_stream_name
  emergency_queue_url            = module.streaming.emergency_queue_url
  sns_owner_topic_arn            = module.streaming.sns_owner_topic_arn
  dynamodb_telemetry_table_name  = module.storage.dynamodb_telemetry_table_name
  iot_role_arn                   = module.security.iot_core_role_arn
  kms_key_id                     = module.security.kms_key_id

  tags = {
    Project = "CCS"
  }
}
```

## References

- [AWS IoT Core Developer Guide](https://docs.aws.amazon.com/iot/latest/developerguide/)
- [MQTT Protocol](https://mqtt.org/)
- [IoT Best Practices](https://docs.aws.amazon.com/iot/latest/developerguide/iot-best-practices.html)

