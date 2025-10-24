# Storage Module

This module implements all data storage layers for the CCS platform.

## Resources Created

### DynamoDB Tables
1. **Telemetry Table**: Real-time vehicle data
   - Partition Key: `vehicle_id`
   - Sort Key: `timestamp`
   - GSI: Status Index
   - TTL: 90 days
   - Streams: Enabled

2. **Incidents Table**: Emergency events
   - Partition Key: `incident_id`
   - Sort Key: `timestamp`
   - GSI: Vehicle Index, Status Index
   - Streams: Enabled

3. **Alerts Config Table**: User alert preferences
4. **WebSocket Connections Table**: Active connections

### RDS Aurora PostgreSQL Serverless v2
- **Engine**: PostgreSQL 15.4
- **Scaling**: 0.5 - 16 ACU
- **Instances**: 2 (Multi-AZ)
- **Backups**: 7 days retention
- **Encryption**: KMS at rest
- **Performance Insights**: Enabled

### ElastiCache Redis 7.0
- **Node Type**: cache.r6g.large
- **Nodes**: 2 (Multi-AZ)
- **Replication**: Automatic failover
- **Encryption**: At rest and in transit
- **Eviction Policy**: allkeys-lru

### S3 Buckets
1. **Data Lake**: Parquet files with intelligent tiering
2. **Videos**: Camera footage with Glacier archival
3. **Logs**: Application and system logs

### Amazon Timestream
- **Database**: Time-series metrics
- **Table**: vehicle_metrics
- **Memory Store**: 24 hours
- **Magnetic Store**: 365 days

## Data Models

### Telemetry Table
```json
{
  "vehicle_id": "VEH-12345",
  "timestamp": 1698765432000,
  "location": {"lat": 4.6097, "lon": -74.0817},
  "speed": 65.5,
  "direction": 180,
  "cargo_temp": 22.5,
  "status": "moving",
  "ttl": 1706541432
}
```

### Incidents Table
```json
{
  "incident_id": "INC-98765",
  "vehicle_id": "VEH-12345",
  "timestamp": 1698765432000,
  "type": "panic_button",
  "severity": "critical",
  "status": "open",
  "location": {"lat": 4.6097, "lon": -74.0817},
  "response_actions": []
}
```

## Performance

### DynamoDB
- **Read/Write**: On-Demand (unlimited)
- **Latency**: <10ms (p99)
- **Availability**: 99.99%

### Aurora PostgreSQL
- **Read Capacity**: 16,000 connections
- **Write Capacity**: Auto-scaling ACUs
- **Latency**: <5ms (local), <20ms (cross-AZ)

### ElastiCache
- **Throughput**: 500,000 ops/sec per node
- **Latency**: Sub-millisecond
- **Memory**: 26.32 GB per r6g.large node

### Timestream
- **Write Throughput**: Millions of records/second
- **Query Performance**: Optimized for time-series
- **Compression**: 10x vs relational databases

## Cost Optimization

### DynamoDB
- **On-Demand**: Pay per request
- **Savings**: Up to 60% with reserved capacity
- **Free Tier**: 25 GB storage

### Aurora
- **Serverless**: Pay per ACU-hour
- **Idle Cost**: $0.06/hour at 0.5 ACU
- **Full Load**: $0.96/hour at 16 ACU

### ElastiCache
- **r6g.large**: ~$0.201/hour
- **Total**: ~$290/month (2 nodes)

### S3
- **Standard**: $0.023 per GB
- **Glacier**: $0.004 per GB
- **Lifecycle**: Automatic cost optimization

### Timestream
- **Memory Store**: $0.036 per GB-hour
- **Magnetic Store**: $0.03 per GB-month
- **Queries**: $0.01 per GB scanned

## Backup & Recovery

### DynamoDB
- Point-in-time recovery enabled
- Streams for change data capture

### Aurora
- Automated backups (7 days)
- Manual snapshots supported
- Cross-region replication (optional)

### ElastiCache
- Daily snapshots
- 5-day retention
- Automatic failover

### S3
- Versioning enabled
- Cross-region replication (optional)
- Lifecycle policies

## Usage

```hcl
module "storage" {
  source = "./modules/storage"

  project_name                    = "ccs"
  environment                     = "prod"
  vpc_id                          = module.networking.vpc_id
  private_subnet_ids              = module.networking.private_subnet_ids
  database_security_group_id      = module.networking.database_security_group_id
  cache_security_group_id         = module.networking.cache_security_group_id
  db_subnet_group_name            = module.networking.db_subnet_group_name
  
  aurora_min_capacity             = 0.5
  aurora_max_capacity             = 16
  elasticache_node_type           = "cache.r6g.large"
  kms_key_id                      = module.security.kms_key_id

  tags = {
    Project = "CCS"
  }
}
```

## Monitoring

### Key Metrics
- DynamoDB: ConsumedReadCapacityUnits, UserErrors
- Aurora: CPUUtilization, DatabaseConnections
- ElastiCache: CacheHitRate, Evictions
- Timestream: SystemErrors, UserErrors
- S3: NumberOfObjects, BucketSizeBytes

