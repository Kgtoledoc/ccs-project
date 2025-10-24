# Streaming Module

This module implements real-time data streaming and messaging for the CCS platform.

## Resources Created

### Kinesis Data Stream
- **Telemetry Stream**: Processes 5,000+ messages/second
- **Shard Configuration**: 10 shards (auto-scales to 50)
- **Retention**: 24 hours
- **Encryption**: KMS at rest

### SQS Queues

#### Emergency Queue (FIFO)
- **Purpose**: Critical events requiring <2s response
- **Type**: FIFO with content-based deduplication
- **Throughput**: High throughput mode (per message group)
- **Visibility Timeout**: 30s
- **Dead Letter Queue**: 3 retries before DLQ

#### Telemetry Queue (Standard)
- **Purpose**: Normal telemetry processing
- **Long Polling**: 20s receive wait time
- **Visibility Timeout**: 60s
- **Dead Letter Queue**: 3 retries before DLQ

### Kinesis Firehose
- **Destination**: S3 Data Lake
- **Format**: Parquet (compressed with GZIP)
- **Buffering**: 128 MB or 5 minutes
- **Partitioning**: year/month/day

### SNS Topics
1. **Authorities Alerts**: Police, ambulance notifications
2. **Owner Alerts**: Vehicle owner notifications
3. **Manager Notifications**: Business approvals
4. **Alarms**: System monitoring alerts

### Auto-Scaling
- **Min Shards**: 10
- **Max Shards**: 50
- **Target Metric**: 1,000 records/shard
- **Scale Out**: 60s cooldown
- **Scale In**: 300s cooldown

## Data Flow

```
IoT Devices → Kinesis Stream ─┬→ Lambda Processors
                               ├→ Firehose → S3 (Parquet)
                               └→ Auto Scaling

Critical Events → SQS FIFO → Lambda (Emergency) → Step Functions → SNS
```

## Performance

### Kinesis Stream
- **Throughput**: 1,000 records/shard/second
- **Base Capacity**: 10,000 records/second
- **Peak Capacity**: 50,000 records/second (auto-scaled)

### SQS Emergency Queue
- **Latency**: <10ms
- **Throughput**: 3,000 messages/second (FIFO)
- **SLA**: Process within 2 seconds

### Firehose
- **Batch Size**: 128 MB
- **Batch Interval**: 5 minutes
- **Compression**: GZIP (reduces storage by ~70%)

## Cost Optimization

### Kinesis
- **Shard Hours**: 10 shards × $0.015/hour = $3.60/day
- **Data PUT**: $0.014 per 1M records
- **Auto-scaling**: Only pay for shards used

### SQS
- **First 1M Requests**: Free
- **Additional**: $0.40 per 1M requests
- **FIFO**: $0.50 per 1M requests

### Firehose
- **Data Ingested**: $0.029 per GB
- **Format Conversion**: $0.018 per GB

### SNS
- **First 1M Publishes**: Free
- **Email**: $2 per 100,000
- **SMS**: Varies by country

## Usage

```hcl
module "streaming" {
  source = "./modules/streaming"

  project_name             = "ccs"
  environment              = "prod"
  kinesis_shard_count      = 10
  kinesis_retention_period = 24
  s3_data_lake_bucket      = "ccs-data-lake-prod"
  kms_key_id               = module.security.kms_key_id

  tags = {
    Project = "CCS"
  }
}
```

## Monitoring

### Key Metrics
- `IncomingRecords`: Records/second to Kinesis
- `IteratorAgeMilliseconds`: Processing lag
- `ApproximateAgeOfOldestMessage`: SQS queue depth
- `NumberOfMessagesSent`: SNS delivery success

### Alarms
- Kinesis iterator age > 60s
- SQS queue depth > 1000 messages
- SNS delivery failures > 5%

## High Availability

- Multi-AZ by default
- Automatic failover
- Dead letter queues for failed messages
- Auto-scaling for traffic spikes

